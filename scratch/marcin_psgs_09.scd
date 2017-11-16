// PSGSPitchShift
// pitch-synchronous granular pitch shifter
// based on Jo Anderson's myMonoPlayBufSynth from DXARTS 462
// (DXARTS_Sp_02b_[Time-segment Processing - Windowed Delays].scd)

/*
quick howto
1. Run codeblock below to access gui with players and shifters
2. Fallback to asynchronous pitchshift or dry sound is attached to the thresholded hasFreq parameter. This might need to be smoothed out
3. Ability to to load multiple soundfiles can help testing pitchshifter with fallback; to load whole directory of soundfiles, use the "open directory of soundfiles" button, then open a single soundfile - all files in that directory will be loaded
4. manual code examples start around line 467; run main code block first, environment vairables are pointing to local variables there
5. CPU load test results are after line 510
*/

(
var synths, notes, buses, buffers;
var window, guiElements, functions;
var liveInbus = 0, outbus = 0; //config input and output (both start at 0)

buses = IdentityDictionary.new;
notes = IdentityDictionary.new;
buffers = IdentityDictionary.new;
guiElements = IdentityDictionary.new;
functions = IdentityDictionary.new;

s.waitForBoot({
	synths = CtkProtoNotes(
		SynthDef(\monoPlayer, { arg buffer, loop=1, amp=1, outbus=0;
			var sig;
			sig = PlayBuf.ar(1, buffer,  BufRateScale.kr(buffer), loop: loop);
			Out.ar(outbus, sig*amp);
		}),
		SynthDef(\monoRouter, { arg inbus=0, outbus=0, amp = 1;
			var sig;
			sig = In.ar(inbus, 1);
			Out.ar(outbus, sig*amp);
		}),
		SynthDef(\monoStereoRouter, { arg inbus=0, outbus=0, amp = 1, pan = 0;
			var sig;
			sig = In.ar(inbus, 1);
			Out.ar(outbus, Pan2.ar(sig, pan, amp));
		}),
		SynthDef(\pitch, { arg inbus = 0, freqOutbus = 0, hasFreqOutbus = 1;
			var in, out, freq, hasFreq;
			in = In.ar(inbus, 1);
			#freq, hasFreq = Tartini.kr(in);//.poll;
			// freq.poll;
			Out.kr(freqOutbus, freq);
			Out.kr(hasFreqOutbus, hasFreq);
		}),
		SynthDef(\threshold, { arg inbus=0, outbus=0, threshold = 0.5;
			var sig;
			sig = In.kr(inbus, 1);
			Out.kr(outbus, sig > threshold);
		}),
		SynthDef(\amp, { arg inbus = 0, ampBus = 1, att = 0.05, rel = 0.2;
			var in, out, amp;
			in = In.ar(inbus, 1);
			amp = Amplitude.kr(in, att, rel);
			Out.kr(ampBus, amp);
		}),
		SynthDef(\PSGPitchShiftDL, {|inbus = 0, freq = 1, outbus = 0, pitchRatio = 1, minFreq = 30, amp = 1|
			var shifted;
			var sig, out;
			sig = In.ar(inbus, 1);
			shifted = PSGPitchShiftDL.ar(sig, freq, pitchRatio, minFreq);
			Out.ar(outbus, shifted * amp)
		}),
		SynthDef(\PSGPitchShiftMT, {|inbus = 0, freq = 1, outbus = 0, pitchRatio = 1, minFreq = 30, amp = 1|
			var shifted;
			var sig, out;
			sig = In.ar(inbus, 1);
			shifted = PSGPitchShiftMT.ar(sig, freq, pitchRatio, minFreq);
			Out.ar(outbus, shifted * amp)
		}),
		//pitch shift
		SynthDef(\PSGPitchShift, {|inbus = 0, amp = 1, freq = 1, outbus = 0, pitchRatio = 1, minFreq = 30, grainPeriods = 2|
			var shifted;
			var sig, out;
			sig = In.ar(inbus, 1);
			shifted = PSGPitchShift.ar(sig, freq, pitchRatio, minFreq, grainPeriods);
			Out.ar(outbus, shifted * amp)
		}),
		//pitch and formant shift
		SynthDef(\PSGPitchFormantShift, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 30, maxFormantRatio = 10, grainPeriods = 2, amp = 1|
			var shifted;
			var sig, out;
			sig = In.ar(inbus, 1);
			shifted = PSGPitchFormantShift.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods);
			Out.ar(outbus, shifted * amp)
		}),
		//with async fallback
		SynthDef(\PSGPitchFormantShift1, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainPeriods = 2, synchronous = 1, asyncPitchChange = 1, asyncGrainRate = 40, asyncGrainPeriods = 4, asyncTimeDispersion = 0.01, asyncPitchDispersion = 0, amp = 1|
			var shifted;
			var sig, out;
			sig = In.ar(inbus, 1);
			shifted = PSGPitchFormantShift1.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods, synchronous, asyncPitchChange, asyncGrainRate, asyncGrainPeriods, asyncTimeDispersion, asyncPitchDispersion); 
			Out.ar(outbus, shifted * amp)
		}),
		//with dry fallback
		SynthDef(\PSGPitchFormantShiftFallback, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 30, maxFormantRatio = 10, grainPeriods = 2, amp = 1, hasFreq = 1, xFadeTime = 0.1|
			var shifted;
			var sig, out;
			sig = In.ar(inbus, 1);
			freq = Gate.kr(freq, hasFreq);
			shifted = PSGPitchFormantShift.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods);
			out = SelectX.ar(hasFreq.lag(xFadeTime), [sig, shifted]);
			Out.ar(outbus, out * amp)
		}),
	);

	//buses

	buses[\audioIn] = CtkAudio(1).play;
	buses[\audioOut] = CtkAudio(1).play;
	buses[\freq] = CtkControl(1).play;
	buses[\hasFreq] = CtkControl(1).play;
	buses[\hasFreqThresholded] = CtkControl(1).play;
	buses[\amp] = CtkControl(1).play;

	//tracker etc
	notes[\freqNote] = synths[\pitch].note(addAction: \head).inbus_(buses[\audioIn]).freqOutbus_(buses[\freq]).hasFreqOutbus_(buses[\hasFreq]).play;
	notes[\ampNote] = synths[\amp].note(addAction: \tail).inbus_(buses[\audioIn]).ampBus_(buses[\amp]).play;
	notes[\monoStereoRouter] = synths[\monoStereoRouter].note(addAction: \tail).inbus_(buses[\audioOut]).outbus_(outbus).play;
	notes[\hasFreqThredhold] = synths[\threshold].note(addAction: \tail).inbus_(buses[\hasFreq]).outbus_(buses[\hasFreqThresholded]).play;


	// for manual examples:
	~buses = buses;
	~synths = synths;


	//functions
	functions[\guiUpdater] = Routine.run({
		loop{
			guiElements[\freqKnob].value_(s.getControlBusValue(buses[\freq].bus));
			guiElements[\hasFreqKnob].value_(s.getControlBusValue(buses[\hasFreq].bus));
			guiElements[\hasFreqThresholdedKnob].value_(s.getControlBusValue(buses[\hasFreqThresholded].bus));
			guiElements[\ampKnob].value_(s.getControlBusValue(buses[\amp].bus).ampdb);
			0.05.wait;
		}
	}, clock: AppClock);

	functions[\loadFiles] = {|path|
		var allFiles;
		if(path.notNil, {
			// path.postln;
			// allFiles = path
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
			((path.dirname ++ "/*.wav").pathMatch ++ (path.dirname ++ "/*.aif*").pathMatch).collect({|thisPath, inc|
				var thisBuffer, thisButton, thisKnob;
				thisBuffer = CtkBuffer.playbuf(thisPath, channels: [0]).load;
				buffers[\array].add(thisBuffer);
				thisKnob = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[(\array ++ inc).asSymbol].amp_(knob.value.dbamp)});
				guiElements[\arrayAmps].add(thisKnob);
				thisButton = Button().states_([[thisPath.basename, nil, Color.hsv(0.38, 0.5, 0.6)], [thisPath.basename, nil, Color.hsv(0.38, 0.5, 0.9)]]).action_({|butt|
					if(butt.value.asBoolean, {
						notes[(\array ++ inc).asSymbol] = synths[\monoPlayer].note(target: notes[\freqNote], addAction: \before).buffer_(thisBuffer).outbus_(buses[\audioIn]).play;
					}, {
						notes[(\array ++ inc).asSymbol].free;
					});
				});
				guiElements[\arrayButtons].add(thisButton);
				guiElements[\playersView].layout.add(
					HLayout(
						thisButton,
						HLayout(
							thisKnob.labelView,
							thisKnob.knobView,
							thisKnob.numberView.maxWidth_(40)
						),
					),
				);
			});
		});
	};

				
	//GUI
	window = Window.new("PSGPitchShift tests", 1200@760).front;
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

	guiElements[\freqKnob] = EZKnob(window, 80@20, "Input freq:", \freq, layout: \horz);
	guiElements[\hasFreqKnob] = EZKnob(window, 80@20, "Has freq:", layout: \horz);
	guiElements[\hasFreqKnobThreshold] = EZKnob(window, 80@20, "[settable] Has freq threshold:", ControlSpec(0.95, 1), layout: \horz).action_({|knob| notes[\hasFreqThredhold].threshold_(knob.value)}).valueAction_(0.99);
	guiElements[\hasFreqKnobThreshold].numberView.maxDecimals_(6);
	guiElements[\hasFreqThresholdedKnob] = EZKnob(window, 80@20, "Has freq after thresh:", layout: \horz);
	guiElements[\ampKnob] = EZKnob(window, 80@20, "Amp (dB):", \db, layout: \horz);


	guiElements[\topView].layout_(
		HLayout(
			Button().states_([["open single file"]]).action_({
				File.openDialog("Choose sound file", {|path|
					buffers[\single].free;
					"Loading file ".post; path.basename.postln;
					buffers[\single] = CtkBuffer.playbuf(path, channels: [0]).load;
				})
			}),
			Button().states_([["open directory of files"]]).action_({
				"Select one audio file (wave/aiff); all files in this directory will be loaded".warn;
				File.openDialog("Open file and all in the same directory",
					{|path|
						functions[\loadFiles].value(path)
					}
				)
			}),
			HLayout(
				guiElements[\hasFreqKnobThreshold].labelView,
				guiElements[\hasFreqKnobThreshold].knobView,
				guiElements[\hasFreqKnobThreshold].numberView.minWidth_(60).maxWidth_(60)
			),
			nil,
			HLayout(
				guiElements[\freqKnob].labelView,
				guiElements[\freqKnob].knobView,
				guiElements[\freqKnob].numberView.maxWidth_(40)
			),
			HLayout(
				guiElements[\hasFreqKnob].labelView,
				guiElements[\hasFreqKnob].knobView,
				guiElements[\hasFreqKnob].numberView.maxWidth_(40)
			),
			HLayout(
				guiElements[\hasFreqThresholdedKnob].labelView,
				guiElements[\hasFreqThresholdedKnob].knobView,
				guiElements[\hasFreqThresholdedKnob].numberView.maxWidth_(40)
			),
			HLayout(
				guiElements[\ampKnob].labelView,
				guiElements[\ampKnob].knobView,
				guiElements[\ampKnob].numberView.maxWidth_(40)
			),
			nil
		)
	);


	//input section

	guiElements[\inputAmpKnob] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\liveInput].amp_(knob.value.dbamp)});
	guiElements[\playerAmpKnob] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\singlePlayer].amp_(knob.value.dbamp)});
	guiElements[\playerButton] = Button().states_([["single buffer player off", nil, Color.hsv(0.3, 0.5, 0.6)], ["single buffer player on", nil, Color.hsv(0.3, 0.5, 0.9)]]).action_({|butt|
		if(buffers[\single].notNil, {
			if(butt.value.asBoolean, {
				notes[\singlePlayer] = synths[\monoPlayer].note(target: notes[\freqNote], addAction: \before).buffer_(buffers[\single]).outbus_(buses[\audioIn]).play;
			}, {
				notes[\singlePlayer].free;
			});
		}, {
			"Load audio file first!".warn;
		});
	});
	
	guiElements[\inputPlayerView].layout_(
		VLayout(
			HLayout(
				Button().states_([["Live input " ++ liveInbus.asString ++ " off", nil, Color.hsv(0.2, 0.5, 0.4)], ["Live input " ++ liveInbus.asString ++ " on", nil, Color.hsv(0.2, 0.5, 0.9)]]).action_({|butt|
					if(butt.value.asBoolean, {
						notes[\liveInput] = synths[\monoRouter].note(target: notes[\freqNote], addAction: \before).inbus_(s.options.numOutputBusChannels + liveInbus).outbus_(buses[\audioIn]).play;
					}, {
						notes[\liveInput].free;
					});
				}),
				HLayout(
					guiElements[\inputAmpKnob].labelView,
					guiElements[\inputAmpKnob].knobView,
					guiElements[\inputAmpKnob].numberView.maxWidth_(40)
				),
			),
			HLayout(
				guiElements[\playerButton],
				HLayout(
					guiElements[\playerAmpKnob].labelView,
					guiElements[\playerAmpKnob].knobView,
					guiElements[\playerAmpKnob].numberView.maxWidth_(40)
				),
			)
		)
	);

	//shifter section
	guiElements[\PSGPitchShiftAmp] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\PSGPitchShift].amp_(knob.value.dbamp)});
	guiElements[\PSGPitchShiftShift] = EZKnob(window, 80@20, "pitch ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| knob.value.postln; notes[\PSGPitchShift].pitchRatio_(knob.value.midiratio)});
	
	guiElements[\PSGPitchFormantShiftAmp] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\PSGPitchFormantShift].amp_(knob.value.dbamp)});
	guiElements[\PSGPitchFormantShiftShift] = EZKnob(window, 80@20, "pitch ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| knob.value.postln; notes[\PSGPitchFormantShift].pitchRatio_(knob.value.midiratio)});
	guiElements[\PSGPitchFormantShiftFormant] = EZKnob(window, 80@20, "formant ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| knob.value.postln; notes[\PSGPitchFormantShift].formantRatio_(knob.value.midiratio)});

	guiElements[\PSGPitchFormantShift1Amp] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\PSGPitchFormantShift1].amp_(knob.value.dbamp)});
	guiElements[\PSGPitchFormantShift1Shift] = EZKnob(window, 80@20, "pitch ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| knob.value.postln; notes[\PSGPitchFormantShift1].pitchRatio_(knob.value.midiratio)});
	guiElements[\PSGPitchFormantShift1Formant] = EZKnob(window, 80@20, "formant ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| knob.value.postln; notes[\PSGPitchFormantShift1].formantRatio_(knob.value.midiratio)});

	guiElements[\PSGPitchFormantShiftFallbackAmp] = EZKnob(window, 80@20, "amp (dB):", \db, layout: \horz).value_(0).action_({|knob| notes[\PSGPitchFormantShiftFallback].amp_(knob.value.dbamp)});
	guiElements[\PSGPitchFormantShiftFallbackShift] = EZKnob(window, 80@20, "pitch ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| knob.value.postln; notes[\PSGPitchFormantShiftFallback].pitchRatio_(knob.value.midiratio)});
	guiElements[\PSGPitchFormantShiftFallbackFormant] = EZKnob(window, 80@20, "formant ratio (semitones):", ControlSpec(-24, 24, default: 0), layout: \horz).value_(0).action_({|knob| knob.value.postln; notes[\PSGPitchFormantShiftFallback].formantRatio_(knob.value.midiratio)});

	guiElements[\shiftersView].layout_(
		VLayout(
			Button().states_([["PSGPitchShift off", nil, Color.hsv(0.15, 0.5, 0.6)], ["PSGPitchShift on", nil, Color.hsv(0.15, 0.5, 0.9)]]).action_({|butt|
				if(butt.value.asBoolean, {
					notes[\PSGPitchShift] = synths[\PSGPitchShift].note(target: notes[\freqNote], addAction: \after).inbus_(buses[\audioIn]).freq_(buses[\freq]).outbus_(buses[\audioOut]).play;
				}, {
					notes[\PSGPitchShift].free;
				});
			}),
			HLayout(
				HLayout(
					guiElements[\PSGPitchShiftAmp].labelView,
					guiElements[\PSGPitchShiftAmp].knobView,
					guiElements[\PSGPitchShiftAmp].numberView.maxWidth_(40)
				),
				HLayout(
					guiElements[\PSGPitchShiftShift].labelView,
					guiElements[\PSGPitchShiftShift].knobView,
					guiElements[\PSGPitchShiftShift].numberView.maxWidth_(40)
				),
			),
			Button().states_([["PSGPitchFormantShift off", nil, Color.hsv(0.16, 0.5, 0.6)], ["PSGPitchFormantShift on", nil, Color.hsv(0.16, 0.5, 0.9)]]).action_({|butt|
				if(butt.value.asBoolean, {
					notes[\PSGPitchFormantShift] = synths[\PSGPitchFormantShift].note(target: notes[\freqNote], addAction: \after).inbus_(buses[\audioIn]).freq_(buses[\freq]).outbus_(buses[\audioOut]).grainPeriods_(2).play;
				}, {
					notes[\PSGPitchFormantShift].free;
				});
			}),
			HLayout(
				HLayout(
					guiElements[\PSGPitchFormantShiftAmp].labelView,
					guiElements[\PSGPitchFormantShiftAmp].knobView,
					guiElements[\PSGPitchFormantShiftAmp].numberView.maxWidth_(40)
				),
				HLayout(
					guiElements[\PSGPitchFormantShiftShift].labelView,
					guiElements[\PSGPitchFormantShiftShift].knobView,
					guiElements[\PSGPitchFormantShiftShift].numberView.maxWidth_(40)
				),
				HLayout(
					guiElements[\PSGPitchFormantShiftFormant].labelView,
					guiElements[\PSGPitchFormantShiftFormant].knobView,
					guiElements[\PSGPitchFormantShiftFormant].numberView.maxWidth_(40)
				),
			),
			Button().states_([["PSGPitchFormantShift with async fallback off", nil, Color.hsv(0.17, 0.5, 0.6)], ["PSGPitchFormantShift with async fallback on", nil, Color.hsv(0.17, 0.5, 0.9)]]).action_({|butt|
				if(butt.value.asBoolean, {
					notes[\PSGPitchFormantShift1] = synths[\PSGPitchFormantShift1].note(target: notes[\freqNote], addAction: \after).inbus_(buses[\audioIn]).freq_(buses[\freq]).synchronous_(buses[\hasFreqThresholded]).outbus_(buses[\audioOut]).grainPeriods_(2).play;
				}, {
					notes[\PSGPitchFormantShift1].free;
				});
			}),
			HLayout(
				HLayout(
					guiElements[\PSGPitchFormantShift1Amp].labelView,
					guiElements[\PSGPitchFormantShift1Amp].knobView,
					guiElements[\PSGPitchFormantShift1Amp].numberView.maxWidth_(40)
				),
				HLayout(
					guiElements[\PSGPitchFormantShift1Shift].labelView,
					guiElements[\PSGPitchFormantShift1Shift].knobView,
					guiElements[\PSGPitchFormantShift1Shift].numberView.maxWidth_(40)
				),
				HLayout(
					guiElements[\PSGPitchFormantShift1Formant].labelView,
					guiElements[\PSGPitchFormantShift1Formant].knobView,
					guiElements[\PSGPitchFormantShift1Formant].numberView.maxWidth_(40)
				),
			),
			Button().states_([["PSGPitchFormantShift with dry fallback xFade off", nil, Color.hsv(0.11, 0.5, 0.6)], ["PSGPitchFormantShift with dry fallback xFade on", nil, Color.hsv(0.11, 0.5, 0.9)]]).action_({|butt|
				if(butt.value.asBoolean, {
					notes[\PSGPitchFormantShiftFallback] = synths[\PSGPitchFormantShiftFallback].note(target: notes[\freqNote], addAction: \after).inbus_(buses[\audioIn]).freq_(buses[\freq]).hasFreq_(buses[\hasFreqThresholded]).outbus_(buses[\audioOut]).grainPeriods_(2).play;//grainbuf
				}, {
					notes[\PSGPitchFormantShiftFallback].free;
				});
			}),
			HLayout(
				HLayout(
					guiElements[\PSGPitchFormantShiftFallbackAmp].labelView,
					guiElements[\PSGPitchFormantShiftFallbackAmp].knobView,
					guiElements[\PSGPitchFormantShiftFallbackAmp].numberView.maxWidth_(40)
				),
				HLayout(
					guiElements[\PSGPitchFormantShiftFallbackShift].labelView,
					guiElements[\PSGPitchFormantShiftFallbackShift].knobView,
					guiElements[\PSGPitchFormantShiftFallbackShift].numberView.maxWidth_(40)
				),
				HLayout(
					guiElements[\PSGPitchFormantShiftFallbackFormant].labelView,
					guiElements[\PSGPitchFormantShiftFallbackFormant].knobView,
					guiElements[\PSGPitchFormantShiftFallbackFormant].numberView.maxWidth_(40)
				),
			),
		)
	);
	

	window.onClose_({
		buses.do(_.free);
		notes.do(_.free);
		buffers.do(_.free);
		functions[\guiUpdater].stop;
	});
});
)

//clear all
(
~buses.do(_.free);
~freqNote.free;
~inNote.free; ~shifterNote.free;
~buffer.free;
~dryRouter.free;
)

(
//start live input
~inNote.free;
~inNote = ~synths[\monoRouter].note(target: ~freqNote, addAction: \before).inbus_(s.options.numOutputBusChannels + 0).outbus_(~buses[\audioIn]).play;
)

(
//buffer
~inNote.free;
~buffer = CtkBuffer.playbuf("b-fl-c3.aiff".resolveRelative, channels: 0).load;
~inNote = ~synths[\monoPlayer].note(0.1, target: ~freqNote, addAction: \before).buffer_(~buffer).outbus_(~buses[\audioIn]).play;
)

//optionally - monitoring of input in the second output
(
~dryRouter = ~synths[\monoRouter].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).outbus_(1).play;
)

s.plotTree

//pitch shifters - choose one
// ~shifterNote = ~synths[\PSGPitchShiftDL].note(addAction: \tail).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//multiple delay lines

// ~shifterNote = ~synths[\PSGPitchShiftMT].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//multi-tap delay

~shifterNote = ~synths[\PSGPitchShift].note(addAction: \tail).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//grainbuf

~shifterNote = ~synths[\PSGPitchFormantShift].note(addAction: \tail).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).play;//grainbuf and formant shifter

~shifterNote = ~synths[\PSGPitchFormantShift1].note(addAction: \tail).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).synchronous_(1).play;//grainbuf and formant shifter with fallback; note that the argument is called "synchronous"

~shifterNote = ~synths[\PSGPitchFormantShiftFallback].note(addAction: \tail).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).hasFreq_(~buses[\hasFreqThresholded]).play;//grainbuf with dry fallback; note that the argument is called "hasFreq"

~shifterNote.free;

~shifterNote.pitchRatio_(0.midiratio)
~shifterNote.pitchRatio_(2.midiratio)
~shifterNote.pitchRatio_(6.midiratio)
~shifterNote.pitchRatio_(-24.midiratio)

~shifterNote.pitchRatio_(CtkControl.env(Env([0.midiratio, 12.midiratio], [10])))

~shifterNote.formantRatio_(0.midiratio)
~shifterNote.formantRatio_(6.midiratio)
~shifterNote.formantRatio_(-6.midiratio)

~shifterNote.formantRatio_(CtkControl.env(Env([0.1, 2], [10])))

~shifterNote.formantRatio_(2)
~shifterNote.formantRatio_(0.8)

~shifterNote.free;

~shifterNote.outbus_(1)

~shifterNote.grainPeriods_(2)
~shifterNote.grainPeriods_(4)

//for shifter with fallback:
~shifterNote.synchronous_(1)
~shifterNote.synchronous_(0)
~shifterNote.asyncPitchChange_(1)
~shifterNote.asyncPitchChange_(0)
~shifterNote.asyncTimeDispersion_(0);
~shifterNote.asyncTimeDispersion_(0.01);
~shifterNote.asyncPitchDispersion_(0);
~shifterNote.asyncPitchDispersion_(0.01);



//------------------
// performance test section
//------------------

//memory and load tests
//performed on MacBook Pro 2012, i7 2.9GHz, 16GB RAM
//hardwareBufferSize default (512)
s.options.hardwareBufferSize
s.makeGui
s.options.memSize_(80000); //for allocating many LocalBufs
s.reboot;

// multiple delay lines
(
l = List.new;
fork{
	80.do({|inc|
		inc.postln;
		l.add(~synths[\PSGPitchShiftDL].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).amp_(0).play;//multiple delay lines
		);
		s.sync;
		// 0.1.wait;
	});
}
)

//PSGPitchShiftDL - multiple delay lines
//80 synths: 65% avg CPU load, peaks > 100% (dropouts)
//80 synths: ~8MB memory allocated dynamically
	
l.do(_.free);


// multitap delay
(
l = List.new;
fork{
	80.do({|inc|
		inc.postln;
		l.add(~synths[\PSGPitchShiftMT].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).amp_(0).play;
		);
		s.sync;
		// 0.1.wait;
	});
}
)

//PSGPitchShiftMT - multitap delay
//80 synths: 60% avg CPU load, peak ~80-90% (mostly no dropouts)
//80 synths: ~4MB memory allocated dynamically
	
l.do(_.free);

//grainbuf implementation - no formant shift
(
l = List.new;
fork{
	80.do({|inc|
		inc.postln;
		l.add(~synths[\PSGPitchShift].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).amp_(0).play;//grainbuf and
		);
		s.sync;
		// 0.1.wait;
	});
}
)

//PSGPitchShift - grainbuf implementation, no formant shift
//80 synths: 14% avg CPU load, peak ~24% (no dropouts)
//80 synths: <2MB memory allocated dynamically
	
l.do(_.free);


//grainbuf implementation - with formant shift
(
l = List.new;
fork{
	80.do({|inc|
		inc.postln;
		l.add(~synths[\PSGPitchFormantShift].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).maxFormantRatio_(10).amp_(0).play;//grainbuf and
		);
		s.sync;
		// 0.1.wait;
	});
}
)

//PSGPitchFormantShift - grainbuf implementation with formant shift - with maxFormantRatio_(10)
//80 synths: 16% avg CPU load, peak ~24% (no dropouts)
//80 synths: ~6MB memory allocated dynamically
	
l.do(_.free);


//grainbuf implementation - with formant shift and asynchronous fallback
(
l = List.new;
fork{
	80.do({|inc|
		inc.postln;
		l.add(~synths[\PSGPitchFormantShift1].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).maxFormantRatio_(10).amp_(0).play;//grainbuf and
		);
		s.sync;
		// 0.1.wait;
	});
}
)

//PSGPitchFormantShift1 - grainbuf implementation with formant shift and asynchronous fallback - with maxFormantRatio_(10)
//80 synths: 19% avg CPU load, peak ~28% (no dropouts)
//80 synths: ~16MB memory allocated dynamically //note minFreq is lower
	
l.do(_.free);



