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


//pitch shifters - choose one
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

~shifterNote.formantRatio_(2)
~shifterNote.formantRatio_(0.8)

~inNote.free; ~shifterNote.free;

~shifterNote.free;

~shifterNote.outbus_(1)

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



