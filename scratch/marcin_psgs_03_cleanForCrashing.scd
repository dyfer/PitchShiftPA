s.makeGui
(
~synth2 = CtkSynthDef(\pugTest, { | inbus = 0, inFreq = 440, ratio = 1, minFreq = 30, // grainPeriods = 2, maxOctaves = 2, 
	outbus = 0|

	var out, grainSig, localbuf, numDelays, grainDur, wavePeriod, trigger, phasor, delaytime, delays, maxdelaytime, grainFreq, bufSize, delayWritePhase;
	var grainPeriods = 2, maxOctaves = 2;
	var in;
	maxdelaytime = minFreq.reciprocal;
	numDelays = grainPeriods * (2**maxOctaves);
	// numDelays = 2 * (2**2);
	bufSize = (SampleRate.ir * maxdelaytime).roundUp;
	// bufSize = SampleRate.ir;
	localbuf = LocalBuf(bufSize, 1).clear;

	wavePeriod = 1.0/inFreq;
	grainDur = grainPeriods * wavePeriod;
	grainFreq = inFreq * ratio;
	
	trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays);
	// trigger = Impulse.ar(grainFreq / numDelays, Array.series(8)/8);
	phasor = LFSaw.ar(inFreq, 1).range(0, wavePeriod);
	delaytime = Latch.ar(phasor, trigger).poll(5, \delaytime);
			CheckBadValues.ar(delaytime, 0, 1);
	// RecordBuf.ar(in, localbuf, 0, 1, 0, 1, 1, 1); 
	// BufWr.ar(in, localbuf, Phasor.ar(1, 1, 0, BufFrames.kr(localbuf), 0), 1); 
	// delays = BufRd.ar(1, localbuf, (Phasor.ar(1, 1, 0, bufSize, 0) - (delaytime * SampleRate.ir)) % bufSize, 1, 4); //this was crashing the server when using LocalBuf, OK with external buffer...
	in = In.ar(inbus, 1);
	delayWritePhase = DelTapWr.ar(localbuf, in);
	delays = DelTapRd.ar(localbuf, delayWritePhase, delaytime, 4); //multiple delays from single buffer
	out = Mix(GrainIn.ar(1, trigger, grainDur, delays));
	
	Out.ar(outbus, out)
})
)

n = ~synth2.note.inbus_(s.options.numOutputBusChannels).play;
n.inFreq_(CtkControl.lfo(SinOsc, 0.5, 400, 600));
n.inFreq_(
n.ratio_(6.midiratio)
n.free

~synth2.synthdef.dumpUGens


//vs
(
~synth1 = CtkSynthDef(\psgs_pug, { | inbus = 0, inFreq = 440, ratio = 1, minFreq = 30, grainPeriods = 2, maxOctaves = 2, outbus = 0|
	var in;
	in = In.ar(inbus, 1);
	Out.ar(outbus, PSGPitchShifter.ar(in, inFreq, ratio, minFreq, grainPeriods, maxOctaves);)
})
)
4.11766e-05 * 1000
n = ~synth1.note.inbus_(s.options.numOutputBusChannels).play;
n.ratio_(6.midiratio);
n.inFreq_(CtkControl.lfo(SinOsc, 0.5, 400, 600));
n.free;
s.boot

(
~pitch = CtkSynthDef(\pitch, { arg inbus, outbus;
	var in, out;
	in = In.ar(inbus, 1);
	out = Tartini.kr(in).poll;
	Out.kr(outbus, out);
});
)
~synth2.synthdef.dumpUGens
~pitchBus = CtkControl.play(1);
n = ~synth2.note.inbus_(s.options.numOutputBusChannels).play;
n.inFreq_(~pitchBus);
o = ~pitch.note.inbus_(s.options.numOutputBusChannels).outbus_(~pitchBus).play;
n.ratio_(6.midiratio)

n.free; o.free;

n = ~synth2.note.inbus_(s.options.numOutputBusChannels).play;
n.inFreq_(~pitchBus);
o = ~pitch.note.inbus_(s.options.numOutputBusChannels).outbus_(~pitchBus).play;

n = ~synth2.note.inbus_(s.options.numOutputBusChannels).inFreq_(~pitchBus).play;
o = ~pitch.note.inbus_(s.options.numOutputBusChannels).outbus_(~pitchBus).play;

n.free; o.free; ~pitchBus.free;




s.makeGui
(
~psPitchShifterUG = CtkSynthDef.new(\psPitchShifterUG, { arg inbus = 0, amp = 1, pitchRatio = 1,
	outbus = 0;

	// variables
	var shifted;
	var sig, out;
	var numChannels = 1; // mono
	var freq = 440.0; // these two should be provided by a pitch tracker (Tartini)
	var hasFreq = 1;

	sig = In.ar(inbus, numChannels);

	#freq, hasFreq = Tartini.kr(sig);
	// #freq, hasFreq = Pitch.kr(sig);

	// freq = DC.kr(freq);

	// freq.poll(5, \freq);

	shifted = PSGPitchShifter.ar(sig, freq, pitchRatio);

	Out.ar(outbus, shifted)
});
)


~psPitchShifterUG.synthdef.dumpUGens


x = ~psPitchShifterUG.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(s.options.numOutputBusChannels).play;
x.pitchRatio_(6.midiratio);
x.free;

(
~synth = CtkSynthDef(\testIn, {|in = 0, out = 0, amp = 1 |
	var localbuf, delayWritePhase, delays, delaytime, sig, trigger, phasor;
	var grainFreq = 576.3;
	var numDelays = 8;
	var inFreq = 576.3;
	var wavePeriod = 200.reciprocal;
	
	localbuf = LocalBuf(SampleRate.ir * 576.3.reciprocal, 1).clear;
	sig = In.ar(in);
	trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays);
	phasor = LFSaw.ar(inFreq, 1).range(0, wavePeriod);
	delaytime = Latch.ar(phasor, trigger);
	// delaytime = [0.2, 0.8];
	
	delayWritePhase = DelTapWr.ar(localbuf, sig);
	delays = Mix(DelTapRd.ar(localbuf, delayWritePhase, delaytime, 4));
	Out.ar(out, delays * amp);
});
)


(
~psPitchShifter = CtkSynthDef.new(\psPitchShifter, { arg
	// arguments
	inbus = 0,
	amp = 1,
	pitchRatio = 1,
	loop = 0,
	buffer = 0,
	outbus = 0,
	freq = 440.0, // these two should be provided by a pitch tracker (Tartini)
	hasFreq = 1;

	// variables
	var envGen;
	var sig, out;
	var numChannels = 1; // mono
	var numDelays;
	var grainPers = 2;
	var octaves = 2;
	var wavPer;
	var trigger, phasor, delaytime;
	var granSig;
	var grainDur;
	var maxdelaytime;
	var grainFreq; // target frequency
	var localbuf, delays;
	var delayWritePhase;


	// set...
	maxdelaytime = 1/15.0; // lowest fundamental freq = 30.0

	numDelays = grainPers * (2**(octaves));

	sig = In.ar(inbus, numChannels);

	#freq, hasFreq = Tartini.kr(sig);

	// freq.poll;

	localbuf = LocalBuf((SampleRate.ir * maxdelaytime).roundUp);
	// localbuf = LocalBuf(SampleRate.ir);

	// calculate wave period and grain duration target frequency
	wavPer = 1.0/freq;
	grainDur = grainPers * wavPer;
	grainFreq = freq * pitchRatio;

	// granular (grain frequency) trigger
	trigger = Impulse.ar(grainFreq / numDelays, Array.series(8)/8); // numDelays separate triggers
	// Out.kr(100, trigger);
	phasor = LFSaw.ar(freq, 1).range(0, wavPer);
	// Out.kr(110, phasor);
	delaytime = Latch.ar(phasor, trigger);
	// Out.kr(120, delaytime * 1000);


	// RecordBuf.ar(sig, localbuf);
	delayWritePhase = DelTapWr.ar(localbuf, sig);

	// delays = delaytime.collect({|thisTime|
	// 	Tap.ar(localbuf, 1, thisTime);
	// });
	// delays = BufRd.ar(1, localbuf, (Phasor.ar(1, 1, 0, BufFrames.kr(localbuf), 0) - (delaytime * SampleRate.ir)) % BufFrames.kr(localbuf), 1, 4);
	delays = DelTapRd.ar(localbuf, delayWritePhase, delaytime, 4);
	// delays = numDelays.asInteger.collect({|inc|
	// 	DelTapRd.ar(localbuf, delayWritePhase, delaytime[inc], 4);
	// });
	// delays = PlayBuf.ar(1, localbuf, 1, trigger, delaytime * SampleRate.ir.neg, 1);

	// delaytime.poll(10, \deltime);
	// delays.poll;


	// granulate
	granSig =  Mix(
		GrainIn.ar(
			numChannels,
			trigger,
			grainDur,
			// DelayC.ar(sig, maxdelaytime, delaytime)
			delays
		)
	)
	;

	// outputs granulated signal if input has pitch
	// otherwise outputs input
	// out = hasFreq.if(granSig, sig);
	out = granSig;

	Out.ar(outbus, out)
});
)
s.reboot;
s.boot;
s.meter
~psPitchShifter.synthdef.dumpUGens;

x = ~psPitchShifter.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(s.options.numOutputBusChannels).play;
x.free;
// triton up
x.pitchRatio_(6.midiratio)

// triton down
x.pitchRatio_(-6.midiratio)
//the same, using pseugo-ugen
(
~psPitchShifterUG = CtkSynthDef.new(\psPitchShifterUG, { arg inbus = 0, amp = 1, pitchRatio = 1,
	outbus = 0;

	// variables
	var shifted;
	var sig, out;
	var numChannels = 1; // mono
	var freq = 440.0; // these two should be provided by a pitch tracker (Tartini)
	var hasFreq = 1;

	sig = In.ar(inbus, numChannels);

	#freq, hasFreq = Tartini.kr(sig);

	// freq.poll;

	shifted = PSGPitchShifter.ar(sig, freq, pitchRatio, hasFreq);

	Out.ar(outbus, shifted)
});
)



{PSGPitchShifter.ar(In.ar(0), 443.2, 1, 1);}.asSynthDef.dumpUGens

~psPitchShifter.synthdef.dumpUGens
~psPitchShifterUG.synthdef.dumpUGens

w = ~pitch.note.inbus_(~bus).outbus_(~ctl).play;

x = ~psPitchShifter.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(~bus).play;

x = ~psPitchShifter.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(s.options.numOutputBusChannels).play;
//live + tartini

x = ~psPitchShifterUG.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(s.options.numOutputBusChannels).play;

s.plotTree
s.meter
x.free
Quarks.gui

(
x = ~psPitchShifterUG.note(addAction: \tail).amp_(0.dbamp).pitchRatio_(1.0).inbus_(~bus).play;
y = ~monoPlayer.note.buffer_(~buffer).loop_(1).outbus_(~bus).play;
)

x.free; y.free;

// set freq and hasFreq to control sigs
x.freq_(~ctl[0]).hasFreq_(~ctl[1])

// 1/4 tone up
x.pitchRatio_(0.5.midiratio)

// 1/4 tone down
x.pitchRatio_(-0.5.midiratio)

// triton up
x.pitchRatio_(6.midiratio)

// triton down
x.pitchRatio_(-6.midiratio)

// actual pitch
x.pitchRatio_(0.midiratio)

w.free
x.free
y.free

~buffer.free
~ctl.free
~bus.free

s.quit

//crash tests

s.boot;

s.makeGui
~synth.synthdef.dumpUGens
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

(
~psPitchShifterUG = CtkSynthDef.new(\psPitchShifterUG, { arg inbus = 0, amp = 1, pitchRatio = 1,
	outbus = 0;

	// variables
	var shifted;
	var sig, out;
	var numChannels = 1; // mono
	var freq = 440.0; // these two should be provided by a pitch tracker (Tartini)
	var hasFreq = 1;

	sig = In.ar(inbus, numChannels);

	// #freq, hasFreq = Tartini.kr(sig);

	// freq.poll;

	shifted = PSGPitchShifter.ar(sig, freq, pitchRatio, hasFreq);

	Out.ar(outbus, shifted)
});
)

x = ~psPitchShifterUG.note.inbus_(s.options.numOutputBusChannels).play;
x.free




/*

	// synthDef.note(starttime: 0.1, duration: buffer.duration).dur_(buffer.duration).amp_(12.dbamp).grainFreq_(587.330 * 2).wavFreq_(587.330).buffer_(buffer),
	// synthDef.note(starttime: 0.1, duration: buffer.duration).dur_(buffer.duration).amp_(12.dbamp).grainFreq_(\c3.hertz * (2**(0.5))).wavFreq_(\c3.hertz).buffer_(buffer),
// );



// play a scale, with original duration:
// myFreqs = 587.330 * [1/1, 9/8, 5/4, 4/3, 3/2, 5/3, 15/8, 2/1];
// myFreqs = \c3.hertz * [1/1, 9/8, 5/4, 4/3, 3/2, 5/3, 15/8, 2/1];
myFreqs = \c3.hertz * [1/1, 0.25.neg.midiratio];

// // or down an octave!!
myFreqs = 2**(-1) * myFreqs;

// // or down two octaves!!
// myFreqs = 2**(-2) * myFreqs;

// // or up an octave!! -- we hear some artefacts....
// myFreqs = 2**(1) * myFreqs;


myFreqs.size.do({ arg i;
	score.add(
		synthDef.note(starttime: 0.1 + (i * buffer.duration), duration: buffer.duration)
		// synthDef.note(starttime: 0.1, duration: buffer.duration)
		.amp_(12.dbamp)
		.dur_(buffer.duration)
		.buffer_(buffer)
		.grainFreq_(myFreqs.at(i))
		// .wavFreq_(587.330)
		.wavFreq_(\c3.hertz)
	)
});



*/

//scratch below...
//From Jo's DX462_Sp_06d_[Windowed Delays - Time-segment Processing].scd
(
var score, synthDef;
var buffer;
var soundFilePath = "154209__carlos-vaquero__transverse-flute-d-5-tenuto-non-vibrato.wav".resolveRelative;
var myFreqs;


~synth = CtkSynthDef.new(\myMonoPlayBufSynth, {arg dur, amp = 1, att = 0.01, rel = 0.01, grainFreq = 20.0,
	wavFreq = 100.0, panPos = 0.0, loop = 1, buffer = 0, gate = 1;
	var envGen;
	var sig, out;
	var numChannels = 1; // mono
	var numDelays;
	var octaves;
	var wavPer, grainPers;
	var trigger, phasor, delaytime;
	var granSig;
	var grainDur;
	var maxdelaytime;

	// set...
	maxdelaytime = 1/15.0; // lowest fundamental freq = 30.0
	grainPers = 2;
	octaves = 2;
	numDelays = grainPers * (2**(octaves));


	// calc
	wavPer = 1.0/wavFreq;
	grainDur = grainPers * wavPer;


	envGen = EnvGen.kr(Env([0, 1, 0], [att, rel], \sin, 1), gate, doneAction: 2);
	envGen = amp * envGen;


	sig = PlayBuf.ar(numChannels, buffer,  BufRateScale.kr(buffer), loop: loop);

	// granular (grain frequency) trigger
	trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays); // numDelays separate triggers
	phasor = LFSaw.ar(wavFreq, 1).range(0, wavPer);
	delaytime = Latch.ar(phasor, trigger);

	// granulate
	granSig = Mix.new(
		GrainIn.ar(
			numChannels,
			trigger,
			grainDur,
			DelayC.ar(sig, maxdelaytime, delaytime)
		)
	);

	out = Pan2.ar(granSig * envGen, panPos);

	Out.ar(
		0,
		out
	)
});


// create the buffer to load soundfile into
~buffer = CtkBuffer.playbuf(
	soundFilePath,
	channels: 0 // just load one channel (left)
).load;
)



// // define the notes / add to score
// // a single note - original pitch
// // D5 = 587.330 Hz
// score.add(
n = ~synth.note.amp_(12.dbamp).grainFreq_(587.330).wavFreq_(587.330).buffer_(~buffer).play;
n.grainFreq_(CtkControl.env(Env([100, 587.33], [10])))
n.grainFreq_(CtkControl.env(Env([587.33 / 2, 587.33], [2])))
n.grainFreq_(587.33 / 2)
n.wavFreq_(587.330 * 1)
n.release;
n.free;


// 	// ~synth.note(starttime: 0.1, duration: buffer.duration).dur_(buffer.duration).amp_(12.dbamp).grainFreq_(587.330 * 2).wavFreq_(587.330).buffer_(buffer),
// 	~synth.note(starttime: 0.1, duration: buffer.duration).dur_(buffer.duration).amp_(12.dbamp).grainFreq_(587.330 * (2**(0))).wavFreq_(587.330).buffer_(buffer),
// );



// play a scale, with original duration:
myFreqs = 587.330 * [1/1, 9/8, 5/4, 4/3, 3/2, 5/3, 15/8, 2/1];

// // or down an octave!!
// myFreqs = 2**(-1) * myFreqs;

// // or down two octaves!!
// myFreqs = 2**(-2) * myFreqs;

// // or up an octave!! -- we hear some artefacts....
// myFreqs = 2**(1) * myFreqs;


myFreqs.size.do({ arg i;
	score.add(
		~synth.note(starttime: 0.1 + (i * buffer.duration), duration: buffer.duration)
		.amp_(12.dbamp)
		.dur_(buffer.duration)
		.buffer_(buffer)
		.grainFreq_(myFreqs.at(i))
		.wavFreq_(587.330)
	)
});



// write the soundfile out to disk
score.write("testCTK.wav".resolveRelative, headerFormat: 'WAV', sampleRate: s.sampleRate, options: ServerOptions.new.numOutputBusChannels_(2));
~path = "testCTK.wav".resolveRelative;
{SFPlayer(~path).gui}.defer(1);
)


