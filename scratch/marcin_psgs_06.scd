// psPitchShifter
// pitch-synchronous granular pitch shifter
// based on Jo Anderson's myMonoPlayBufSynth from DXARTS 462
// (DXARTS_Sp_02b_[Time-segment Processing - Windowed Delays].scd)


s.boot;
s.makeGui
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
		// freq.poll;
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
	SynthDef(\PSGPitchShift, {|inbus = 0, amp = 1, freq = 1, outbus = 0, pitchRatio = 1, minFreq = 30, grainPeriods = 2|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		shifted = PSGPitchShift.ar(sig, freq, pitchRatio, minFreq, grainPeriods);
		Out.ar(outbus, shifted * amp)
	}),
	SynthDef(\PSGPitchFormantShift, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 30, maxFormantRatio = 10, grainPeriods = 2, amp = 1|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		shifted = PSGPitchFormantShift.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods);
		Out.ar(outbus, shifted * amp)
	}),
	SynthDef(\PSGPitchFormantShift1, {|inbus = 0,  freq = 1, outbus = 0, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainPeriods = 2, synchronous = 1, asyncPitchChange = 1, asyncGrainRate = 10, asyncGrainPeriods = 4, asyncTimeDispersion = 0.01, asyncPitchDispersion = 0, amp = 1|
		var shifted;
		var sig, out;
		sig = In.ar(inbus, 1);
		shifted = PSGPitchFormantShift1.ar(sig, freq, pitchRatio, formantRatio, minFreq, maxFormantRatio, grainPeriods, synchronous, asyncPitchChange, asyncGrainRate, asyncGrainPeriods, asyncTimeDispersion, asyncPitchDispersion);
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


//pitch shifters
~shifterNote = ~synths[\PSGPitchShiftDL].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//multiple delay lines

~shifterNote = ~synths[\PSGPitchShiftMT].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//multi-tap delay

~shifterNote = ~synths[\PSGPitchShift].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).play;//grainbuf

~shifterNote = ~synths[\PSGPitchFormantShift].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).play;//grainbuf and formant shifter

~shifterNote = ~synths[\PSGPitchFormantShift1].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).play;//grainbuf and formant shifter with fallback

s.makeGui

~shifterNote.pitchRatio_(0.midiratio)
~shifterNote.pitchRatio_(2.midiratio)
~shifterNote.pitchRatio_(6.midiratio)
~shifterNote.pitchRatio_(-6.midiratio)

~shifterNote.pitchRatio_(CtkControl.env(Env([0.midiratio, 12.midiratio], [10])))

~shifterNote.formantRatio_(0.midiratio)
~shifterNote.formantRatio_(6.midiratio)
~shifterNote.formantRatio_(-6.midiratio)

~shifterNote.formantRatio_(CtkControl.env(Env([0.1, 2], [10])))

~shifterNote.formantRatio_(1.1)
~shifterNote.formantRatio_(0.8)

~inNote.free; ~shifterNote.free;

~shifterNote.free;


//for shifter with fallback:
~shifterNote.synchronous_(1)
~shifterNote.synchronous_(0)
~shifterNote.transitionTimeD_(0)
~shifterNote.transitionTimeU_(0)
~shifterNote.synchronous_(CtkControl.env(Env([0, 1], [1])))
~shifterNote.synchronous_(CtkControl.env(Env([1, 0], [1])))
~shifterNote.asyncPitchChange_(1)
~shifterNote.asyncPitchChange_(0)
~shifterNote.asyncTimeDispersion_(0);
~shifterNote.asyncTimeDispersion_(0.01);
~shifterNote.asyncPitchDispersion_(0);
~shifterNote.asyncPitchDispersion_(0);




//further tests
~shifterNote = ~synth2.note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).maxFormantRatio_(10).play;//grainbuf and formant shifter
s.scope

~shifterNote.formantRatio_(1)

~shifterNote.formantRatio_(CtkControl.env(Env([0.5, 2], [10])))
// ~shifterNote.phasorOffset_(0)

s.makeGui
s.scope
//fallback
~shifterNote = ~synth3.note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).maxFormantRatio_(10).play;

~shifterNote = ~synth3.note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).formantRatio_(1).maxFormantRatio_(10).synchronous_(0).pitchRatio_(6.midiratio).play;
s.scope
~shifterNote.synchronous_(1)
~shifterNote
~shifterNote.transitionTimeD_(0)
~shifterNote.transitionTimeU_(0)
~shifterNote.synchronous_(CtkControl.env(Env([0, 1], [1])))
~shifterNote.synchronous_(CtkControl.env(Env([1, 0], [1])))
~shifterNote.asyncPitchChange_(1)
~shifterNote.asyncPitchChange_(0)

~shifterNote.asyncPitchDispersion_(0)
~shifterNote.asyncTimeDispersion_(0)

~shifterNote.pitchRatio_(0.midiratio)
~shifterNote.pitchRatio_(16.midiratio)
~shifterNote.pitchRatio_(1.1.midiratio)
~shifterNote.pitchRatio_(4)
~shifterNote.pitchRatio_(-6.midiratio)
~shifterNote.pitchRatio_(0.9)
s.makeGui
64*s.sampleRate.reciprocal
(s.sampleRate / s.options.blockSize).reciprocal //0.0013333333333333
~shifterNote.phasorOffset_(0.0013333333333333)
~shifterNote.phasorOffset_(0.2)
~shifterNote.phasorOffset_(0)
~shifterNote.phasorOffset_(0.7)
~shifterNote.phasorOffset_(0.6)

~shifterNote.asyncGrainRate
~shifterNote.asyncGrainRate_(20)
~shifterNote.asyncGrainPeriods

~shifterNote.free;

s.getControlBusValue(100)



-> 0.099999994039536





~shifterNote.formantRatio_(0.midiratio)
~shifterNote.formantRatio_(6.midiratio)
~shifterNote.formantRatio_(-6.midiratio)

~shifterNote.asyncGrainRate_(20)


//this sounds cool when synchronous = 0, but it's wrong
(
PSGPitchFormantShift1 { //GrainBuf implementation using a circular buffer - with formant shift and asynchronous granulation fallback
	*ar { | in, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainPeriods = 2, synchronous = 1, asyncPitchChange = 1, asyncGrainRate = 10, asyncGrainPeriods = 2, asyncTimeDispersion = 0.1, asyncPitchDispersion = 0.1|

		var out, grainSig, localbuf, grainDur, wavePeriod, trigger, freqPhase, grainPos, delaytime, maxdelaytime, grainFreq, bufSize, delayWritePhase, pitchRatioAsync;
		
		minFreq = minFreq.max(0.001); //protect agains division by 0 further down
		maxdelaytime = minFreq.reciprocal;
		formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);
		bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
		localbuf = LocalBuf(bufSize, 1).clear;

		freq = freq.max(minFreq);

		wavePeriod = SelectX.ar(synchronous, [
			K2A.ar(asyncGrainRate.max(0.001).reciprocal),
			K2A.ar(freq.reciprocal)
		]);
		grainDur = SelectX.ar(synchronous, [
			K2A.ar(asyncGrainPeriods),
			K2A.ar(grainPeriods * wavePeriod)
		]);
		grainFreq = freq * pitchRatio;
		
		trigger = Impulse.ar(SelectX.kr(synchronous, [
			asyncGrainRate + Dust2.kr(asyncGrainRate, asyncTimeDispersion),
			grainFreq
		]));
		pitchRatioAsync = Dust2.ar(asyncGrainRate, asyncPitchDispersion) + (pitchRatio * (asyncPitchChange > 0));
		freqPhase = SelectX.ar(synchronous, [
			pitchRatioAsync * wavePeriod * (pitchRatioAsync > 1),
			LFSaw.ar(freq, 1).range(0, wavePeriod) + (formantRatio * wavePeriod * (formantRatio > 1));//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase!
		]);
			// CheckBadValues.ar(delaytime, 0, 1);
		formantRatio = Select.kr(synchronous, [
			Select.kr(asyncPitchChange, [
				1,
				pitchRatioAsync //async formant ratio -> pitch shift
			]),
			formantRatio //synchronous formant ratio
		]);
		delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
		grainPos = (delayWritePhase / BufFrames.kr(localbuf)) - (freqPhase / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
		out = GrainBuf.ar(1, trigger, grainDur, localbuf, formantRatio, grainPos);
		^out;
	}
}
)


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
s.meter

//unsynchronized granulation fallback
(
~synth3 = CtkSynthDef(\grainBufFallbackTest, { | inbus = 0, outbus = 0, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 5, maxFormantRatio = 10, grainPeriods = 2, synchronous = 1, asyncPitchChange = 1, asyncGrainRate = 10, asyncGrainPeriods = 2, asyncTimeDispersion = 0.1, asyncPitchDispersion = 0.1, transitionTimeU = 0, transitionTimeD = 0.1, phasorOffset = 0|

	var out, grainSig, localbuf, numDelays, grainDur, wavePeriod, trigger, phasor, phasorScaled, delaytime, delays, maxdelaytime, grainFreq, bufSize, delayWritePhase, in;
	var trigger1, pitchRatio1, phasor1; //for async operation
	minFreq = minFreq.max(0.001);
	in = In.ar(inbus, 1);
	maxdelaytime = minFreq.reciprocal;
	formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);
	bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
	localbuf = LocalBuf(bufSize, 1).clear;

	freq = freq.max(minFreq);
	
	wavePeriod = SelectX.ar(synchronous.lagud(transitionTimeU, transitionTimeD), [K2A.ar(asyncGrainRate.max(0.001).reciprocal), K2A.ar(freq.reciprocal)]); //added select for asynchronous
	// grainDur = Select.ar(synchronous, [K2A.ar(asyncGrainPeriods), K2A.ar(grainPeriods)]) * wavePeriod; //added select for asynchronous
	grainDur = Select.ar(synchronous, [K2A.ar(asyncGrainPeriods), K2A.ar(grainPeriods)]) * wavePeriod; //added select for asynchronous
	grainFreq = freq * pitchRatio;
	
	// trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays);
	trigger = Impulse.ar(
		// grainFreq
		SelectX.kr(synchronous.lagud(transitionTimeU, transitionTimeD), [asyncGrainRate + Dust2.kr(asyncGrainRate, asyncTimeDispersion), grainFreq])
	);
	// trigger1 = Impulse.kr();
	// trigger = Select.ar(synchronous, [K2A.ar(trigger1), trigger]);
	phasor = LFSaw.ar(freq, 1).range(0, wavePeriod);
	// Out.kr(120, phasor);
	// Out.kr(121, ((formantRatio.max(1) - phasorOffset) * wavePeriod));
	phasor = phasor + (formantRatio * wavePeriod * (formantRatio > 1));//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase! phasorOffset was here previously
	pitchRatio1 = Dust2.ar(asyncGrainRate, asyncPitchDispersion) + ((asyncPitchChange > 0) * pitchRatio);
	// phasor1 = (pitchRatio1.lag(0.1) * wavePeriod.lag(0.1) * (pitchRatio1 > 1));
	// phasor1 = ((pitchRatio1 - 1) * wavePeriod * (pitchRatio1 > 1));
	// phasor1 = ((pitchRatio1 - 1) * wavePeriod * (pitchRatio1 > 1)) + phasorOffset;
	// phasor1 = phasorOffset;
	phasor1 = ((pitchRatio1 - 1) * grainDur * (pitchRatio1 > 1));	
	// phasor1 = (pitchRatio1 * wavePeriod * (pitchRatio1 > 1) * 0.5) + (ControlDur.ir * (pitchRatio1 > 1));
	Out.kr(100, phasor1);
	phasor = Select.ar(synchronous, [K2A.ar(phasor1), phasor]); //not elegant... choose proper phasor
	// Out.kr(122, phasor);
	// CheckBadValues.ar(delaytime, 0, 1);
	delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
	phasorScaled = (delayWritePhase / BufFrames.kr(localbuf)) - (phasor / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
	// formantRatio = Select.kr((synchronous + asyncPitchChange) * (synchronous != 0), [formantRatio, 1, pitchRatio1]);
	formantRatio = Select.kr(synchronous, [
		pitchRatio1,
		Select.kr(asyncPitchChange, [1, formantRatio])
	]);	
	out = GrainBuf.ar(1, trigger, grainDur, localbuf, formantRatio, phasorScaled);
	Out.ar(outbus, out);
})
)


//unsynchronized granulation fallback - old
(
~synth3 = CtkSynthDef(\grainBufFallbackTest, { | inbus = 0, outbus = 0, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 5, maxFormantRatio = 10, grainPeriods = 2, synchronous = 1, asyncPitchChange = 1, asyncGrainRate = 10, asyncGrainPeriods = 2, asyncTimeDispersion = 0.1, asyncPitchDispersion = 0.1|

	var out, grainSig, localbuf, numDelays, grainDur, wavePeriod, trigger, phasor, phasorScaled, delaytime, delays, maxdelaytime, grainFreq, bufSize, delayWritePhase, in;
	var trigger1, grainRatio1, phasor1; //for async operation
	minFreq = minFreq.max(0.001);
	in = In.ar(inbus, 1);
	maxdelaytime = minFreq.reciprocal;
	formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);
	bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
	localbuf = LocalBuf(bufSize, 1).clear;

	freq = freq.clip(minFreq, inf);
	
	wavePeriod = Select.kr(synchronous, [asyncGrainRate.max(0.001).reciprocal, freq.reciprocal]); //added select for asynchronous
	grainDur = Select.kr(synchronous, [asyncGrainPeriods, grainPeriods]) * wavePeriod; //added select for asynchronous
	grainFreq = freq * pitchRatio;
	
	// trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays);
	trigger = Impulse.ar(grainFreq);
	trigger1 = Impulse.kr(asyncGrainRate + Dust.kr(asyncGrainRate, asyncTimeDispersion));
	trigger = Select.ar(synchronous, [K2A.ar(trigger1), trigger]);
	phasor = LFSaw.ar(freq, 1).range(0, wavePeriod);
	// Out.kr(120, phasor);
	// Out.kr(121, ((formantRatio.max(1) - phasorOffset) * wavePeriod));
	phasor = phasor + (formantRatio * wavePeriod * (formantRatio > 1));//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase! phasorOffset was here previously
	grainRatio1 = Dust.kr(asyncGrainRate, asyncPitchDispersion) + ((asyncPitchChange > 0) * pitchRatio);
	phasor1 = (grainRatio1 * wavePeriod * (grainRatio1 > 1));
	phasor = Select.ar(synchronous, [K2A.ar(phasor1), phasor]); //not elegant... choose proper phasor
	// Out.kr(122, phasor);
	// CheckBadValues.ar(delaytime, 0, 1);
	delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
	phasorScaled = (delayWritePhase / BufFrames.kr(localbuf)) - (phasor / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
	formantRatio = Select.kr((synchronous + asyncPitchChange) * (synchronous != 0), [formantRatio, 1, pitchRatio]);
	out = GrainBuf.ar(1, trigger, grainDur, localbuf, formantRatio, phasorScaled);
	Out.ar(outbus, out);
})
)





//memory and load tests
//performed on i7 2.9GHz
//hardwareBufferSize default (512)
s.options.hardwareBufferSize
s.makeGui
s.options.memSize_(80000);
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
//80 synths: 65% avg CPU load, peak > 100% (dropouts)
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
//80 synths: 60% avg CPU load, peak ~90% (no dropouts)
//80 synths: ~4MB memory allocated dynamically
	
l.do(_.free);

//grainbuf implementation - no formant shift
(
l = List.new;
fork{
	80.do({|inc|
		inc.postln;
		l.add(~synths[\PSGPitchShiftGB].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).amp_(0).play;//grainbuf and
		);
		s.sync;
		// 0.1.wait;
	});
}
)

//PSGPitchShiftGB - grainbuf implementation, no formant shift
//80 synths: 14% avg CPU load, peak ~24% (no dropouts)
//80 synths: <2MB memory allocated dynamically
	
l.do(_.free);


//grainbuf implementation - with formant shift
(
l = List.new;
fork{
	80.do({|inc|
		inc.postln;
		l.add(~synths[\PSGPitchShift].note(target: ~freqNote, addAction: \after).inbus_(~buses[\audioIn]).freq_(~buses[\freq]).maxFormantRatio_(10).amp_(0).play;//grainbuf and
		);
		s.sync;
		// 0.1.wait;
	});
}
)

//PSGPitchShift - grainbuf implementation - with maxFormantRatio_(10)
//80 synths: 14% avg CPU load, peak ~24% (no dropouts)
//80 synths: ~6MB memory allocated dynamically
	
l.do(_.free);

