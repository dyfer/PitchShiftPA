// psPitchShifter
// pitch-synchronous granular pitch shifter
// based on Jo Anderson's myMonoPlayBufSynth from DXARTS 462
// (DXARTS_Sp_02b_[Time-segment Processing - Windowed Delays].scd)
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


	// set...
	maxdelaytime = 1/15.0; // lowest fundamental freq = 30.0

	numDelays = grainPers * (2**(octaves));

	sig = In.ar(inbus, numChannels);

	// calculate wave period and grain duration target frequency
	wavPer = 1.0/freq;
	grainDur = grainPers * wavPer;
	grainFreq = freq * pitchRatio;

	// granular (grain frequency) trigger
	trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays); // numDelays separate triggers
	phasor = LFSaw.ar(freq, 1).range(0, wavPer);
	delaytime = Latch.ar(phasor, trigger);

	// granulate
	granSig = Mix(
		GrainIn.ar(
			numChannels,
			trigger,
			grainDur,
			DelayC.ar(sig, maxdelaytime, delaytime)
		)
	);

	// outputs granulated signal if input has pitch
	// otherwise outputs input
	out = hasFreq.if(granSig, sig);

	Out.ar(outbus, out*amp)
});
)

s.boot;

(
// stuff we need for testing

// create the buffer to load soundfile into
~buffer = CtkBuffer.playbuf(
	"/Users/juan/Snd/b-fl-c3.aiff",
	// "/Volumes/Data/Projects/Finished/VuKarpen/Snd/Trumpet/Trumpet_6.wav",
	channels: 0 // just load one channel (left)
).load(sync: true);

~monoPlayer = CtkSynthDef(\monoPlayer, { arg buffer, loop=1, amp=1, outbus=0;
	var sig;
	sig = PlayBuf.ar(1, buffer,  BufRateScale.kr(buffer), loop: loop);
	Out.ar(outbus, sig*amp);
});

~pitch = CtkSynthDef(\pitch, { arg inbus, outbus;
	var in, out;
	in = In.ar(inbus, 1);
	out = Tartini.kr(in).poll;
	Out.kr(outbus, out);
});
)

~bus = CtkAudio(1);
~ctl = CtkControl(2);

w = ~pitch.note.inbus_(~bus).outbus_(~ctl).play;

x = ~psPitchShifter.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(~bus).play;

y = ~monoPlayer.note.buffer_(~buffer).loop_(1).outbus_(~bus).play;

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