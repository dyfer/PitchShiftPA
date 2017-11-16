// psPitchShifter
// pitch-synchronous granular pitch shifter
// based on Jo Anderson's myMonoPlayBufSynth from DXARTS 462
// (DXARTS_Sp_02b_[Time-segment Processing - Windowed Delays].scd)


s.boot;
s.plotTree;
//all synths
(
~synths = CtkProtoNotes(
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
		freq.poll;
		Out.kr(freqOutbus, freq);
		Out.kr(hasFreqOutbus, hasFreq);
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
	SynthDef(\PSGPitchShiftGB, {|inbus = 0, amp = 1, freq = 1, outbus = 0, pitchRatio = 1, minFreq = 30, grainPeriods = 2|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		shifted = PSGPitchShiftGB.ar(sig, freq, pitchRatio, minFreq, grainPeriods);
		Out.ar(outbus, shifted * amp)
	}),
	SynthDef(\PSGPitchShift, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 30, maxFormantRatio = 10, grainPeriods = 2, amp = 1|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		shifted = PSGPitchShift.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods);
		Out.ar(outbus, shifted * amp)
	}),
);
)

//init buses and pitch tracker
(
~buses = IdentityDictionary.new;
~buses[\audioIn] = CtkAudio(1);
~buses[\freq] = CtkControl(1);
~buses[\hasFreq] = CtkControl(1);
~freqNote = ~synths[\pitch].note(addAction: \tail).inbus_(~buses[\audioIn]).freqOutbus_(~buses[\freq]).hasFreqOutbus_(~buses[\hasFreq]).play;
)

//clear all
(
~buses.do(_.free);
~freqNote.free;
~inNote.free; ~shifterNote.free;
~buffer.free;
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

~shifterNote = ~synths[\PSGPitchShiftDL].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//multiple delay lines

~shifterNote = ~synths[\PSGPitchShiftMT].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//multi-tap delay

~shifterNote = ~synths[\PSGPitchShiftGB].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//grainbuf

~shifterNote = ~synths[\PSGPitchShift].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).play;//grainbuf and formant shifter

~shifterNote = ~synths[\PSGPitchShift].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).play;//grainbuf and formant shifter


~shifterNote.pitchRatio_(0.midiratio)
~shifterNote.pitchRatio_(6.midiratio)
~shifterNote.pitchRatio_(-6.midiratio)

~shifterNote.formantRatio_(0.midiratio)
~shifterNote.formantRatio_(6.midiratio)
~shifterNote.formantRatio_(-6.midiratio)

~shifterNote.formantRatio_(CtkControl.env(Env([0.1, 2], [10])))

~shifterNote.formantRatio_(1.8)

~inNote.free; ~shifterNote.free;

~shifterNote.free;


~shifterNote = ~synth2.note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).maxFormantRatio_(10).play;//grainbuf and formant shifter
s.scope

~shifterNote.formantRatio_(8)
~shifterNote.phasorOffset_(0)


~dryRouter = ~synths[\monoRouter].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).outbus_(1).play;
~dryRouter.outbus_(1)

1.1.max(1) - 1


(
~synth2 = CtkSynthDef(\grainBufTest, { | inbus = 0, outbus = 0, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainPeriods = 2, phasorOffset = 1|

		var out, grainSig, localbuf, numDelays, grainDur, wavePeriod, trigger, phasor, phasorScaled, delaytime, delays, maxdelaytime, grainFreq, bufSize, delayWritePhase, in;
		minFreq = minFreq.max(0.001);
		in = In.ar(inbus, 1);
		maxdelaytime = minFreq.reciprocal;
		formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);
		bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
		localbuf = LocalBuf(bufSize, 1).clear;

		freq = freq.clip(minFreq, inf);

		wavePeriod = 1.0/freq;
		grainDur = grainPeriods * wavePeriod;
		grainFreq = freq * pitchRatio;
		
		// trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays);
		trigger = Impulse.ar(grainFreq);
	phasor = LFSaw.ar(freq, 1).range(0, wavePeriod);
	Out.kr(120, phasor);
	Out.kr(121, ((formantRatio.max(1) - phasorOffset) * wavePeriod));
	phasor = phasor + (formantRatio * wavePeriod * (formantRatio > 1));//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase! phasorOffset was here previously
	Out.kr(122, phasor);
		// CheckBadValues.ar(delaytime, 0, 1);
		delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
		phasorScaled = (delayWritePhase / BufFrames.kr(localbuf)) - (phasor / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
		out = GrainBuf.ar(1, trigger, grainDur, localbuf, formantRatio, phasorScaled);
		Out.ar(outbus, out);
})
)

n = ~synth2.note.inbus_(s.options.numOutputBusChannels).play;
n.ratio_(6.midiratio)
n.free

~synth2.synthdef.dumpUGens




(
fork{
	1000.do({|inc|
		inc.postln;
		n = ~synth.note(0, 0.1).in_(s.options.numOutputBusChannels).amp_(-90.dbamp).play;
		0.05.wait;
	});
}
)
	
n.free

(
r = Routine.run({
	1000.do({|inc|
		inc.postln;
		~synth.note(0, 0.3).in_(s.options.numOutputBusChannels).amp_(-90.dbamp).play;
		0.02.wait;
	})
});
)
	
s.boot
s.meter