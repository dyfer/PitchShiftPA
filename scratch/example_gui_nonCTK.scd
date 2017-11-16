(
var synths, notes, buses, buffers;
var window, guiElements, functions;
var liveInbus = 0, outbus = 0; //config input and output

buses = IdentityDictionary.new;
notes = IdentityDictionary.new;
buffers = IdentityDictionary.new;
guiElements = IdentityDictionary.new;
functions = IdentityDictionary.new;

s.waitForBoot({
	SynthDef(\monoPlayer, { arg buffer, loop=1, amp=1, outbus=0;
		var sig;
		sig = PlayBuf.ar(1, buffer,  BufRateScale.kr(buffer), loop: loop);
		Out.ar(outbus, sig*amp);
	}).add;
	SynthDef(\monoRouter, { arg inbus=0, outbus=0, amp = 1;
		var sig;
		sig = In.ar(inbus, 1);
		Out.ar(outbus, sig*amp);
	}).add;
	SynthDef(\monoStereoRouter, { arg inbus=0, outbus=0, amp = 1, pan = 0;
		var sig;
		sig = In.ar(inbus, 1);
		Out.ar(outbus, Pan2.ar(sig, pan, amp));
	}).add;
	SynthDef(\pitch, { arg inbus = 0, freqOutbus = 0, hasFreqOutbus = 1;
		var in, out, freq, hasFreq;
		in = In.ar(inbus, 1);
		#freq, hasFreq = Pitch.kr(in);
		// freq.poll;
		Out.kr(freqOutbus, freq);
		Out.kr(hasFreqOutbus, hasFreq);
	}).add;
	SynthDef(\amp, { arg inbus = 0, ampBus = 1, att = 0.05, rel = 0.2;
		var in, out, amp;
		in = In.ar(inbus, 1);
		amp = Amplitude.kr(in, att, rel);
		Out.kr(ampBus, amp);
	}).add;
	//pitch shift only
	SynthDef(\PitchShiftPA_light, {|inbus = 0, amp = 1, freq = 1, outbus = 0, pitchRatio = 1, minFreq = 30, grainPeriods = 2|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		shifted = PitchShiftPA.ar(sig, freq, pitchRatio, nil, minFreq, nil, grainPeriods);
		Out.ar(outbus, shifted * amp)
	}).add;
	//pitch and formant shift
	SynthDef(\PitchShiftPA, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 30, maxFormantRatio = 10, grainPeriods = 2, amp = 1|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		shifted = PitchShiftPA.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods);
		Out.ar(outbus, shifted * amp)
	}).add;
	//with 'dry' signal fallback
	SynthDef(\PitchShiftPA_fallback, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 30, maxFormantRatio = 10, grainPeriods = 2, amp = 1, hasFreq = 1, xFadeTime = 0.1|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		freq = Gate.kr(freq, BinaryOpUGen('==',  hasFreq, 1)); //only pass frequencies when the tracker is confident
		shifted = PitchShiftPA.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods);
		out = SelectX.ar(hasFreq.lag(xFadeTime), [sig, shifted]);
		Out.ar(outbus, out * amp)
	}).add;

	//buses
	buses[\audioIn] = Bus.audio(s, 1);
	buses[\audioOut] = Bus.audio(s, 1);
	buses[\freq] = Bus.control(s, 1);
	buses[\hasFreq] = Bus.control(s, 1);
	buses[\amp] = Bus.control(s, 1);

	//tracker etc
	notes[\freqNote] = Synth(\pitch, [\inbus, buses[\audioIn], \freqOutbus, buses[\freq], \hasFreqOutbus, buses[\hasFreq]], addAction: \addToHead);
	notes[\ampNote] = Synth(\amp, [\inbus, buses[\audioIn], \ampBus, buses[\amp]], addAction: \addToHead);
	notes[\monoStereoRouter] = Synth(\monoStereoRouter, [\inbus, buses[\audioOut], \outbus, outbus], addAction: \addToTail);

	//functions
	functions[\guiUpdater] = Routine.run({
		loop{
			guiElements[\freqKnob].value_(buses[\freq].getSynchronous);
			guiElements[\hasFreqKnob].value_(buses[\hasFreq].getSynchronous);
			guiElements[\ampKnob].value_(buses[\amp].getSynchronous.ampdb);
			0.05.wait;
		}
	}, clock: AppClock);

	functions[\loadFiles] = {|path, single = false|
		var allFiles;
		if(path.notNil, {
			buffers[\array].do(_.free);
			guiElements[\arrayButtons].do(_.remove);
			guiElements[\arrayAmps].do({|thisKnob|
				thisKnob.labelView.remove;
				thisKnob.knobView.remove;
				thisKnob.numberView.remove;
			});
			buffers[\array] = List.new;
			guiElements[\arrayButtons] = List.new;
			guiElements[\arrayAmps] = List.new;
			notes.keysValuesDo({|key, value|
				if(key.asString.includes("array"), {
					value.free;
				});
			});
			if(single, {
				allFiles = [path];
			}, {
				allFiles = ((path.dirname ++ "/*.wav").pathMatch ++ (path.dirname ++ "/*.aif*").pathMatch);
			});
			allFiles.collect({|thisPath, inc|
				var thisBuffer, thisButton, thisKnob;
				thisBuffer = Buffer.read(s, thisPath);
				buffers[\array].add(thisBuffer);
				thisKnob = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[(\array ++ inc).asSymbol].set(\amp, knob.value.dbamp)});
				guiElements[\arrayAmps].add(thisKnob);
				thisButton = Button().states_([[thisPath.basename, nil, Color.hsv(0.38, 0.5, 0.6)], [thisPath.basename, nil, Color.hsv(0.38, 0.5, 0.9)]]).action_({|butt|
					if(butt.value.asBoolean, {
						notes[(\array ++ inc).asSymbol] = Synth(\monoPlayer, [\buffer, thisBuffer, \outbus, buses[\audioIn]], target: notes[\ampNote], addAction: \addBefore);
					}, {
						notes[(\array ++ inc).asSymbol].free;
					});
				});
				guiElements[\arrayButtons].add(thisButton);
				guiElements[\playersView].layout.add(
					HLayout(
						thisButton.maxWidth_(300),
						nil,
						thisKnob.labelView,
						thisKnob.knobView,
						thisKnob.numberView.maxWidth_(40)
					),
				);
			});
		});
	};


	//GUI
	window = Window.new("PitchShiftPA tests", 1200@760).front;
	guiElements[\playersView] = View.new;
	guiElements[\playersView].layout_(VLayout());
	guiElements[\inputPlayerView] = View.new;
	guiElements[\shiftersView] = View.new;
	guiElements[\topView] = View.new;
	window.layout_(
		VLayout(
			guiElements[\topView],
			HLayout(
				VLayout(
					StaticText().string_("Sound sources:").font_(Font(size: 24)),
					guiElements[\inputPlayerView],
					guiElements[\playersView]
				),
				VLayout(
					StaticText().string_("Pitch shifters:").font_(Font(size: 24)),
					guiElements[\shiftersView]
				);
			),
			nil //space at the bottom
		)
	);

	guiElements[\freqKnob] = EZKnob(window, 80@20, "freq:", \freq, layout: \horz);
	guiElements[\hasFreqKnob] = EZKnob(window, 80@20, "has freq:", layout: \horz);
	guiElements[\ampKnob] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz);


	guiElements[\topView].layout_(
		VLayout(
			StaticText().string_("Tester for PitchShiftPA. Use live input or monophonic (single-channel, as well as single-voice) soud files (use buttons below to load).\nButtons on the right turndifferent pitch shifters on and off .\nPlease note, that the accuracy of pitch tracking of the input has a crucial effect on the result."),
			HLayout(
				Button().states_([["open sound file"]]).action_({
					File.openDialog("Choose sound file", {|path|
						functions[\loadFiles].value(path, true)
					})
				}),
				Button().states_([["open all sound files in a directory"]]).action_({
					"Select one audio file (wave/aiff); all files in this directory will be loaded".warn;
					File.openDialog("Choose one of the files in the directory",
						{|path|
							functions[\loadFiles].value(path, false)
						}
					)
				}),
				nil,
			)

		)
	);


	//input section

	guiElements[\inputAmpKnob] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\liveInput].set(\amp, knob.value.dbamp)});

	guiElements[\inputPlayerView].layout_(
		VLayout(
			StaticText().string_("parameters of the sound (updated live):").minWidth_(200),
			HLayout(
				guiElements[\freqKnob].labelView,
				guiElements[\freqKnob].knobView,
				guiElements[\freqKnob].numberView.maxWidth_(60),
				guiElements[\hasFreqKnob].labelView,
				guiElements[\hasFreqKnob].knobView,
				guiElements[\hasFreqKnob].numberView.maxWidth_(40),
				guiElements[\ampKnob].labelView,
				guiElements[\ampKnob].knobView,
				guiElements[\ampKnob].numberView.maxWidth_(60)
			),
			nil,
			HLayout(
				Button().states_([["Live input " ++ liveInbus.asString ++ " off", nil, Color.hsv(0.2, 0.5, 0.4)], ["Live input " ++ liveInbus.asString ++ " on", nil, Color.hsv(0.2, 0.5, 0.9)]]).action_({|butt|
					if(butt.value.asBoolean, {
						notes[\liveInput] = Synth(\monoRouter, [\inbus, s.options.numOutputBusChannels + liveInbus, \outbus, buses[\audioIn]], target: notes[\ampNote], addAction: \addBefore);
					}, {
						notes[\liveInput].free;
					});
				}),
				nil,
				guiElements[\inputAmpKnob].labelView,
				guiElements[\inputAmpKnob].knobView,
				guiElements[\inputAmpKnob].numberView.maxWidth_(40)
			),
		)
	);

	//shifter section
	guiElements[\PitchShiftPA_lightAmp] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\PitchShiftPA_light].set(\amp, knob.value.dbamp)});
	guiElements[\PitchShiftPA_lightShift] = EZKnob(window, 80@20, "pitch ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob|  notes[\PitchShiftPA_light].set(\pitchRatio, knob.value.midiratio)});

	guiElements[\PitchShiftPAAmp] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\PitchShiftPA].set(\amp, knob.value.dbamp)});
	guiElements[\PitchShiftPAShift] = EZKnob(window, 80@20, "pitch ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| notes[\PitchShiftPA].set(\pitchRatio, knob.value.midiratio)});
	guiElements[\PitchShiftPAFormant] = EZKnob(window, 80@20, "formant ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| notes[\PitchShiftPA].set(\formantRatio, knob.value.midiratio)});

	guiElements[\PitchShiftPA_fallbackAmp] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\PitchShiftPA_fallback].set(\amp, knob.value.dbamp)});
	guiElements[\PitchShiftPA_fallbackShift] = EZKnob(window, 80@20, "pitch ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob|  notes[\PitchShiftPA_fallback].set(\pitchRatio, knob.value.midiratio)});
	guiElements[\PitchShiftPA_fallbackFormant] = EZKnob(window, 80@20, "formant ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob|  notes[\PitchShiftPA_fallback].set(\formantRatio, knob.value.midiratio)});

	guiElements[\shiftersView].layout_(
		VLayout(
			Button().states_([["PitchShiftPA_light off", nil, Color.hsv(0.15, 0.5, 0.6)], ["PSGPitchShiftPA_light on", nil, Color.hsv(0.15, 0.5, 0.9)]]).action_({|butt|
				if(butt.value.asBoolean, {
					notes[\PitchShiftPA_light] = Synth(\PitchShiftPA_light, [\inbus, buses[\audioIn], \freq, buses[\freq].asMap, \outbus, buses[\audioOut]], target: notes[\freqNote], addAction: \addAfter);
				}, {
					notes[\PitchShiftPA_light].free;
				});
			}),
			HLayout(
				guiElements[\PitchShiftPA_lightAmp].labelView,
				guiElements[\PitchShiftPA_lightAmp].knobView,
				guiElements[\PitchShiftPA_lightAmp].numberView.maxWidth_(50),
				guiElements[\PitchShiftPA_lightShift].labelView,
				guiElements[\PitchShiftPA_lightShift].knobView,
				guiElements[\PitchShiftPA_lightShift].numberView.maxWidth_(50),
				nil,
			),
			Button().states_([["\PitchShiftPA off", nil, Color.hsv(0.16, 0.5, 0.6)], ["PitchShiftPA on", nil, Color.hsv(0.16, 0.5, 0.9)]]).action_({|butt|
				if(butt.value.asBoolean, {
					notes[\PitchShiftPA] = Synth(\PitchShiftPA, [\inbus, buses[\audioIn], \freq, buses[\freq].asMap, \outbus, buses[\audioOut]], target: notes[\freqNote], addAction: \addAfter);
				}, {
					notes[\PitchShiftPA].free;
				});
			}),
			HLayout(
				guiElements[\PitchShiftPAAmp].labelView,
				guiElements[\PitchShiftPAAmp].knobView,
				guiElements[\PitchShiftPAAmp].numberView.maxWidth_(50),
				guiElements[\PitchShiftPAShift].labelView,
				guiElements[\PitchShiftPAShift].knobView,
				guiElements[\PitchShiftPAShift].numberView.maxWidth_(50),
				guiElements[\PitchShiftPAFormant].labelView,
				guiElements[\PitchShiftPAFormant].knobView,
				guiElements[\PitchShiftPAFormant].numberView.maxWidth_(50),
				nil,
			),
			Button().states_([["PitchShiftPA with 'dry' fallback off", nil, Color.hsv(0.11, 0.5, 0.6)], ["PitchShiftPA with 'dry' fallback on", nil, Color.hsv(0.11, 0.5, 0.9)]]).action_({|butt|
				if(butt.value.asBoolean, {
					notes[\PitchShiftPA_fallback] = Synth(\PitchShiftPA_fallback, [\inbus, buses[\audioIn], \freq, buses[\freq].asMap, \hasFreq, buses[\hasFreq].asMap, \outbus, buses[\audioOut]], target: notes[\freqNote], addAction: \addAfter);
				}, {
					notes[\PitchShiftPA_fallback].free;
				});
			}),
			HLayout(
				guiElements[\PitchShiftPA_fallbackAmp].labelView,
				guiElements[\PitchShiftPA_fallbackAmp].knobView,
				guiElements[\PitchShiftPA_fallbackAmp].numberView.maxWidth_(50),
				guiElements[\PitchShiftPA_fallbackShift].labelView,
				guiElements[\PitchShiftPA_fallbackShift].knobView,
				guiElements[\PitchShiftPA_fallbackShift].numberView.maxWidth_(50),
				guiElements[\PitchShiftPA_fallbackFormant].labelView,
				guiElements[\PitchShiftPA_fallbackFormant].knobView,
				guiElements[\PitchShiftPA_fallbackFormant].numberView.maxWidth_(50),
				nil,
			),
		)
	);

	window.onClose_({
		functions[\guiUpdater].stop;
		buses.asArray.flat.do(_.free);
		notes.asArray.flat.do(_.free);
		buffers.asArray.flat.do(_.free);
	});
});
)
