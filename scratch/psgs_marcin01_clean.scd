s.reboot
//the same, using pseugo-ugen
(
~psPitchShifterUG = CtkSynthDef.new(\psPitchShifterUG, { arg inbus = 0, amp = 1, pitchRatio = 1,
	outbus = 0;

	var shifted;
	var sig, out;
	var numChannels = 1; // mono
	var freq = 440.0; // these two should be provided by a pitch tracker (Tartini)
	var hasFreq = 1;

	sig = In.ar(inbus, numChannels);

	#freq, hasFreq = Tartini.kr(sig);

	shifted = PSGPitchShift.ar(sig, freq, pitchRatio, 10);

	Out.ar(outbus, shifted)
});
~psPitchFormantShifterUG = CtkSynthDef.new(\psPitchFormantShifterUG, { arg inbus = 0, amp = 1, pitchRatio = 1, formantRatio = 1,
	outbus = 0;

	var shifted;
	var sig, out;
	var numChannels = 1; // mono
	var freq = 440.0; // these two should be provided by a pitch tracker (Tartini)
	var hasFreq = 1;

	sig = In.ar(inbus, numChannels);

	#freq, hasFreq = Tartini.kr(sig);

	shifted = PSGPitchFormantShift.ar(sig, freq, pitchRatio, formantRatio, 1, 10);

	Out.ar(outbus, shifted)
});

~psPitchFormantShifter1UG = CtkSynthDef.new(\psPitchFormantShifter1UG, { arg inbus = 0, amp = 1, pitchRatio = 1, formantRatio = 1,
	outbus = 0, sync = 1, asyncPitchChange = 1, asyncGrainRate = 40, asyncGrainPeriods = 4, asyncTimeDispersion = 0, asyncPitchDispersion = 0;

	var shifted;
	var sig, out;
	var numChannels = 1; // mono
	var freq = 440.0; // these two should be provided by a pitch tracker (Tartini)
	var hasFreq = 1;

	sig = In.ar(inbus, numChannels);

	#freq, hasFreq = Tartini.kr(sig);
	// freq.poll;
//in, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainPeriods = 2, synchronous = 1, asyncPitchChange = 1, asyncGrainRate = 40, asyncGrainPeriods = 4, asyncTimeDispersion = 0.01, asyncPitchDispersion = 0.01|
	shifted = PSGPitchFormantShift1.ar(sig, freq, pitchRatio, formantRatio, 0.5, 10, 2, sync, asyncPitchChange, asyncGrainRate, asyncGrainPeriods, asyncTimeDispersion, asyncPitchDispersion);

	Out.ar(outbus, shifted)
});
)


//test with live input - pitch shifter
x.free; x = ~psPitchShifterUG.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(s.options.numOutputBusChannels).play;

//test with live input - pitch shifter with formant
x.free; x = ~psPitchFormantShifterUG.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(s.options.numOutputBusChannels).play;

//test with live input - pitch shifter with formant and fallback
x.free; x = ~psPitchFormantShifter1UG.note.amp_(0.dbamp).pitchRatio_(1.0).inbus_(s.options.numOutputBusChannels).play;


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

//formant
x.formantRatio_(7.midiratio)
x.formantRatio_(0.midiratio)

x.sync_(0)
x.sync_(1)
x.asyncGrainRate_(5)
x.asyncPitchDispersion_(0.2)
x.asyncTimeDispersion_(0.8)
)

//free
x.free;

//or with sample, below
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
~bus = CtkAudio(1);
)

(
x = ~psPitchShifterUG.note(addAction: \tail).amp_(0.dbamp).pitchRatio_(1.0).inbus_(~bus).play;
y = ~monoPlayer.note.buffer_(~buffer).loop_(1).outbus_(~bus).play;
)

x.free; y.free; ~bus.free;

