// psPitchShifter
// pitch-synchronous granular pitch shifter
// based on Jo Anderson's myMonoPlayBufSynth from DXARTS 462
// (DXARTS_Sp_02b_[Time-segment Processing - Windowed Delays].scd)
s.boot;

MultiTap  {

	*ar { arg timesArray, levelsArray, in = 0.0, mul = 1.0, add = 0.0,bufnum;

		var sampleRate;
		timesArray = timesArray.dereference;
		levelsArray = levelsArray.dereference;
		RecordBuf.ar(in,bufnum,0.0, run: -1.0);
		sampleRate = BufSampleRate.kr(bufnum);

		^Mix.fill(timesArray.size,{ arg i;
			PlayBuf.ar(in.numChannels,
					bufnum, -1.0,1.0,
					timesArray.at(i) * sampleRate,
					loop: 1)
				.madd(levelsArray.at(i) ? 1.0)
		}).madd(mul,add);
	}
}



Tap : UGen {
	*ar { arg bufnum = 0, numChannels = 1, delaytime = 0.2;
		var n;
		n = delaytime * SampleRate.ir.neg; // this depends on the session sample rate, not buffer.
		^PlayBuf.ar(numChannels, bufnum, 1, 0, n, 1);
	}
}

//----
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

	localbuf = LocalBuf(SampleRate.ir * maxdelaytime);

	// calculate wave period and grain duration target frequency
	wavPer = 1.0/freq;
	grainDur = grainPers * wavPer;
	grainFreq = freq * pitchRatio;

	// granular (grain frequency) trigger
	trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays); // numDelays separate triggers
	Out.kr(100, trigger);
	phasor = LFSaw.ar(freq, 1).range(0, wavPer);
	Out.kr(110, phasor);
	delaytime = Latch.ar(phasor, trigger);
	Out.kr(120, delaytime * 1000);


	// RecordBuf.ar(sig, localbuf);
	delayWritePhase = DelTapWr.ar(localbuf, sig);

	// delays = delaytime.collect({|thisTime|
	// 	Tap.ar(localbuf, 1, thisTime);
	// });
	// delays = BufRd.ar(1, localbuf, (Phasor.ar(1, 1, 0, BufFrames.kr(localbuf), 0) - (delaytime * SampleRate.ir)) % BufFrames.kr(localbuf), 1, 4);
	delays = DelTapRd.ar(localbuf, delayWritePhase, delaytime, 4);
	// delays = PlayBuf.ar(1, localbuf, 1, trigger, delaytime * SampleRate.ir.neg, 1);

	// delaytime.poll(10, \deltime);
	// delays.poll;


	// granulate
	granSig = Mix(
		GrainIn.ar(
			numChannels,
			trigger,
			grainDur,
			// DelayC.ar(sig, maxdelaytime, delaytime)
			delays
		)
	);

	// outputs granulated signal if input has pitch
	// otherwise outputs input
	// out = hasFreq.if(granSig, sig);
	out = granSig;

	Out.ar(outbus, [out, 0, 0])
});
)
s.boot
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

(
// stuff we need for testing

// create the buffer to load soundfile into
~buffer = CtkBuffer.playbuf(
	"b-fl-c3.aiff".resolveRelative,
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