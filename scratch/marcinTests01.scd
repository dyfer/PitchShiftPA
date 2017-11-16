
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