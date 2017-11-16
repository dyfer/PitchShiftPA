/* DXARTS 462 Digital Sound Processing: Class 2 - Time-segment Processing / Pitch Synchronous Granular Synthesis */



// Time-segment Processing - Outline

/*

- Introduction
    - Time-segment Processing / Granular Synthesis
    - Granular Synthesis review
        - SGS
        - parameters

- Time Stretch (or Contract) with GrainBuf (SGS)
    - simple indexing
    - pitch synchronous indexing (PCGS)

- Asynchronous Granular Synthesis
    - DIY!!

*/



/*

Many of the Time-segment Processing techniques reviewed by Zolzer can be viewed as variations or various implementions of Granular Synthesis. Which term we use may be a matter of convenience, or be chosen to emphasise a certain approach to implementing an algorithm. The term Time-segment Processing is often chosen to describe algorithms intended to operate (process) input streams (or buffers).

Of course, Granular Synthesis as a synthesis technique isn't fixed to the use of synthesised waveforms, which is the approach we explored in DXARTS 461. It will help to review our efforts with Complex Waveforms:

DX461_Wi_08a_[SGS - Complex Waveforms]
DX461_Wi_08b_[AGS - Complex Waveforms]

In the above listed code we analysed a small portion of a sound to create a single grain (waveform packet). This packet was then assembled into a granular stream. Today we'll look at extracting multiple grains (waveform packets) from our input sound. The synthesised result can return the exact input, time stretched or pitch shifted versions. As you can imagine, this technique returns a variety of interesting and creative possibilities!

With our below discussion, we'll start by looking at time stretching.... refining this to reduce artefacts, and then modify to generate pitch shifted results.

*/


// start server!
Server.default = s = Server.local.boot; // use this for SC-IDE


// open the displays..
(
var numChannels = 2; // for the scope

// display!
Stethoscope.new(s, numChannels);
FreqScope.new;
)


// ------------------------------------------------------------------

/*

Granular Synthesis Review: types / parameters
(review from DX461)


---
Sychronous Granular Synthesis (SGS), using enveloped sinusoids: granular stream triggered at a regular rate


D&J use SGS to mean grains are generated at a continuous rate, at a "synchronous" "fundamental" frequency.

For review, the parameters of SGS are:

fg : grain frequency (grain rate), in Hz
dg : grain duration (grain period), in secs
fw : enveloped waveform frequency(s) (frequency(s) of enveloped waveform), in Hz


And... we'd seen that it is often more convenient to define grain duration (dg) in terms of a frequency. We'll call this term the grain envelope frequency (fe). Where:

fe = 1 / dg


So now, our terms are:

fg : grain frequency (grain rate), in Hz
fe : grain envelope frequency (1 / grain duration), in Hz
fw : enveloped waveform frequency (frequency of enveloped sine wave), in Hz


These correlate to:

fg: grain frequency, controls the fundamental frequency
fw: enveloped waveform frequency, controls the formant center frequency
fe: grain envelope frequency, controls the bandwidth


Then we saw that it is more convenient to describe Simple Sinusoid SGS in terms of:

f: resulting fundamental frequency, in Hz
ff: resulting formant frequency, in Hz
q: resulting formant "quality"


The mapping for Simple Sinusoid SGS is:

fg = f
fw = ff
fe = 1/q * ff / 2

*/


/*

---
Sychronous Granular Synthesis (SGS), using complex waveforms: granular stream triggered at a regular rate


For Complex Waveform SGS, we have the following parameters:

f: resulting fundamental frequency, in Hz
fr: reference waveform frequency, in Hz
r: waveform resampling ratio


The first parameter is obvious. This is our target synthesis fundamental frequency. The reference waveform frequency (fr) is the analysis frequency of the waveform in question. This value will be used to correctly window the input sound in question. (And, allows us to resynthesis the formant structure correctly.) The final value, waveform resampling ratio (r), allows us to move the formant structure up or down. A ratio of 1 keeps the spectrum at the original location. A value of 2 moves it an octave up, and a value of 0.5 shift the spectrum down an octave.

So... these parameters allow us to separate the fundamental and the location of the sampled formant structure.


The mapping to SGS synthesis parameters looks like this:

fg = f;
fe = r * fr / 2


You'll notice this looks very similar to the mapping for Simple Sinusoid SGS, however, we're missing:

enveloped waveform frequency (fw)

In Simple Sinusoid SGS fw contains formant information. In Complex Waveform SGS, the formant information is contained in the complex waveform!

*/




// ------------------------------------------------------------------

/*

Time Stretch (or Contract) with GrainBuf (SGS)


A simple method to time stretch a recorded sound is to take time-segments from a sound, and then repeat until we get our desired new length. The most simple example of this is just looping! Suppose we'd like to double the length of a sound. If we just play the sound twice through, we'll get double the original length. We saw this last week, implemented by setting the PlayBuf loop flag to 1.

Admittedly, looping isn't particularly sophisticated, BUT if used well, we can get attractive musical results a la Oswald's "Bell Speeds".

We're here to be a bit more nuanced, however. What we'll do, instead, is to take small time-segments, and slowly increment through the sound in question. These segments will be used as grains (with envelopes) to create a granular stream.

-----

Before we attempt to use the mapping of Complex Waveform SGS synthesis parameters illustrated above, let's touch the SGS parameters directly.... (We'll get smarter about this in this next example!)


Parameters we'll want to touch (for now):

fg : grain frequency (grain rate), in Hz
fe : grain envelope frequency (1 / grain duration), in Hz
fr : enveloped waveform frequency(s) (frequency(s) of enveloped waveform), in Hz


For the moment, we'll just be controlling grain frequency (fg) and grain envelope frequency (fe). Enveloped waveform frequency(s) (fr) (usually a complex waveform, with many frequencies) is determined by the recording itself. We may know fr, or we may not! (Better if we do, for pitched sounds!)

Enveloped waveform frequency (fr) can be adjusted after the fact by touching the resampling ratio (r) of the sampled buffer. This will give us the following parameters:


fg : grain frequency (grain rate), in Hz
fe : grain envelope frequency (1 / grain duration), in Hz
r : enveloped waveform resampling ratio, as a ratio


*/





/*

We'll start our exploration by looking at time stretching...

*/



// GrainBuf and CtkBuffer - mono - Time-stretch
//
// ATTRIBUTION:
// Downloaded on April 3rd, 2014
// S: Transverse-Flute D-5 Tenuto Non-Vibrato by Carlos_Vaquero -- http://www.freesound.org/people/Carlos_Vaquero/sounds/154209/ -- License: Attribution Noncommercial
//
// grainFreq --> fg : grain frequency
// envFreq   --> fe : grain envelope frequency (1 / grain duration)
// wavRatio  --> r  : enveloped waveform resampling ratio
(
var score, synthDef;
var buffer;
var soundFilePath = "154209__carlos-vaquero__transverse-flute-d-5-tenuto-non-vibrato.wav".resolveRelative;


synthDef = CtkSynthDef.new(\myGrainBufSynth, {arg dur, amp = 1, ris = 0.1, dec = 0.1, grainFreq = 20.0, envFreq = 10.0,
	wavRatio = 1, panPos = 0.0, loop = 0, buffer = 0;

	var ampEnvGen;
	var trigger;
	var grainDur;
	var sig, out;
	var indx;
	var numChannels = 1; // mono


	// calculate grainDur
	grainDur = envFreq.reciprocal;

	// note envelope
	ampEnvGen = EnvGen.kr(
		Env.linen(ris, dur - (ris + dec), dec) // env define within synthDef
	);
	ampEnvGen = ampEnvGen * amp;

	// buffer position (index)
	indx = Line.ar(0, 1, dur);

	// granular (grain frequency) trigger
	trigger = Impulse.ar(grainFreq);

	// granular synthesis
	sig = GrainBuf.ar(numChannels: numChannels, trigger: trigger,
		dur: grainDur, sndbuf: buffer, rate: BufRateScale.kr(buffer) * wavRatio, pos: indx);

	// pan
	out = ampEnvGen * Pan2.ar(sig, panPos);

	Out.ar(
		0,
		out
	)
});

// create the buffer to load soundfile into
buffer = CtkBuffer.playbuf(
	soundFilePath,
	channels: 0 // just load one channel (left)
);


// create a score
score = CtkScore.new;

// add the buffer to the score
// NOTE: buffers must be added to the score for the CtkSynthDef to access!
score.add(buffer);


// EXAMPLE 1
//
// same duration
// -- additively reconstructs original sound!
//
// NOTE: no need to touch grainFreq, envFreq, or ratio
// score.add(synthDef.note(starttime: 0.1, duration: buffer.duration).dur_(buffer.duration).buffer_(buffer));


// // EXAMPLE 2
// //
// // 4 * duration
// // -- not bad, but can hear some windowing, which sounds like AM
// //
// // NOTE: grainFreq, grainDur, or ratio set to default values...
score.add(synthDef.note(starttime: 0.1, duration: 4 * buffer.duration).amp_(6.dbamp).dur_(4 * buffer.duration).buffer_(buffer));


// // EXAMPLE 3
// //
// // stretch to 30 sec
// // -- can hear more windowing, and also notice some emphasis in higher harmonics (sounds metallic)
// score.add(synthDef.note(starttime: 0.1, duration: 30.0).amp_(6.dbamp).dur_(30.0).buffer_(buffer));


// // EXAMPLE 4
// //
// // stretch to 30 sec
// // bigger window size - can hear the grain rate... because windows don't overlap
// // sounds like RM, because it is!!
// score.add(synthDef.note(starttime: 0.1, duration: 30.0).amp_(12.dbamp).dur_(30.0).buffer_(buffer).grainFreq_(10.0).envFreq_(10.0));


// // EXAMPLE 5
// //
// // stretch to 30 sec
// // more RM!!
// //
// // NOTE: if we make a little bit of effort, knowing the fundamental frequency of the input waveform
// //       we can do some calculations and control the RM spectrum being generated... which can be really useful!!
// score.add(synthDef.note(starttime: 0.1, duration: 30.0).amp_(12.dbamp).dur_(30.0).buffer_(buffer).grainFreq_(300.0).envFreq_(300.0));


// // EXAMPLE 6
// //
// // stretch to 30 sec
// // tune grainFreq and envFreq to sampled buffer frequency
// // D5 = 587.330 Hz
// //
// // -- hmm... still sounds metallic! and we also have a sub-harmonic tone, too!!
// score.add(synthDef.note(starttime: 0.1, duration: 30.0).amp_(9.dbamp).dur_(30.0).buffer_(buffer).grainFreq_(587.330).envFreq_(587.330/2));


// write the soundfile out to disk
score.write("testCTK.wav".resolveRelative, headerFormat: 'WAV', sampleRate: s.sampleRate, options: ServerOptions.new.numOutputBusChannels_(2));
~path = "testCTK.wav".resolveRelative;
{SFPlayer(~path).gui}.defer(1);
)
SFPlayer("testCTK.wav".resolveRelative).gui;


/*

For this last example we've set the grainFreq to be equal to the frequency of the sampled flute recording, AND set the size of the grain to hold two periods of the sampled waveform. We've chosen these values with the notion that with tuning the grain frequency and grain duration to the fundamental found in our sampled waveform will give a more transparent result. As you recall, this is the strategy described by Keith Lent to choose the grain size.

Lent, Keith. "An Efficient Method for Pitch Shifting Digitally Sampled Sounds." Computer Music Journal. 13.4 (1989): 65-71. Print.


With this last example, we're not getting a transparent result! In fact, we hear some artefacts that may be described as 'metalic'. This ends up being a result of a combination of phase modulation and amplitude modulation, caused by indexing into the sampled waveform and the grain envelope itself.


Below... we'll seek to improve the situation by taking into account both the input wavform frequency AND the phase of this input waveform.

*/





// ------------------------------------------------------------------

/*

Pitch Synchronous Time Stretch (or Contract) with GrainBuf (PSGS or PSOLA)


To avoid the phase modulation effects heard above (with a pitched sound source) we have two options. The first of these is to randomise the index into the sampled waveform so that a regular modulation does not occur. This works for both pitched and un-pitched sources. For pitched sources we have another choice: only index into the sampled waveform at integer sampled waveform periods. Doing this avoids phase modulation of the sampled sound.

If we're going to take this approach, we need to let the algorithm know (fundamental) frequency of the sampled waveform. Additionally, we'll find it convenient to tie the grain envelope frequency (1 / grain duration) to this period. Doing so will allow the granular synthesis algorithm to return wave packets extracted from the input sound at a specified rate (the old, or even a new, fundamental frequency)....



-----
Let's review the parameters for Complex Waveform SGS, again:


f: resulting fundamental frequency, in Hz
fr: reference waveform frequency, in Hz
r: waveform resampling ratio


We had seen (in DX461) the mapping to SGS synthesis parameters looks like this:

fg = f;
fe = r * fr / 2

Where fg is the grain frequency and fe is grain envelope frequency (1 / grain duration). In the calculation of grain envelope frequency we see a fixed scalar of 1/2. If you recall, this is as a result of Lent's recommendation that the windowed waveform packet contain two cycles. For convenience, we can expose this value as a parameter:

wp : number of enveloped waveform periods


The mapping for grain envelope frequency now looks like this:


fe = r * fr / wp


In this form, we're back to a similar parameter set as we'd used with Complex Waveform SGS in DXARTS 461. Here we're assuming that the input sound is pitched, and we know the fundamental. The envelope frequency is then mapped to this. We can now to pitch shifting, time stretching, and formant shifting, all with a single algorithm!

*/




// GrainBuf and CtkBuffer - mono - Pitch-synchronous time-stretch (& pitch-shift)
//
// ATTRIBUTION:
// Downloaded on April 3rd, 2014
// S: Transverse-Flute D-5 Tenuto Non-Vibrato by Carlos_Vaquero -- http://www.freesound.org/people/Carlos_Vaquero/sounds/154209/ -- License: Attribution Noncommercial
//
// freq     --> f  : fundamental frequency
// refFreq  --> fr : reference waveform frequency
// wavRatio --> r  : waveform resampling ratio
// grainPers    --> gp : number of enveloped grain periods
(
var score, synthDef;
var buffer;
var soundFilePath = "154209__carlos-vaquero__transverse-flute-d-5-tenuto-non-vibrato.wav".resolveRelative;
var myFreqs;
var myRatios;


synthDef = CtkSynthDef.new(\myGrainBufSynth, {arg dur, amp = 1, ris = 0.1, dec = 0.1, freq = 440.0,
	wavRatio = 1, refFreq = 440.0, grainPers = 2, panPos = 0.0, loop = 0, buffer = 0;

	var ampEnvGen;
	var trigger;
	var envFreq, grainFreq, grainDur;
	var sig, out;
	var indx;
	var numChannels = 1; // mono
	var bufferPers; // total number of sampled waveform periods


	// map / calculate SGS parameters
	grainFreq = freq;
	envFreq = wavRatio * refFreq / grainPers;
	grainDur = envFreq.reciprocal;
	bufferPers = refFreq * BufDur.kr(buffer);

	// note envelope
	ampEnvGen = EnvGen.kr(
		Env.linen(ris, dur - (ris + dec), dec) // env define within synthDef
	);
	ampEnvGen = ampEnvGen * amp;

	// buffer position (index)
	indx = Line.ar(0, 1, dur);
	indx = (indx * bufferPers).floor / bufferPers; // round index to sync to whole period offsets


	// granular (grain frequency) trigger
	trigger = Impulse.ar(grainFreq);

	// granular synthesis
	sig = GrainBuf.ar(numChannels: numChannels, trigger: trigger, dur: grainDur, sndbuf: buffer, rate: BufRateScale.kr(buffer) * wavRatio, pos: indx);

	// pan
	out = ampEnvGen * Pan2.ar(sig, panPos);

	Out.ar(
		0,
		out
	)
});


// create the buffer to load soundfile into
buffer = CtkBuffer.playbuf(
	soundFilePath,
	channels: 0 // just load one channel (left)
);


// create a score
score = CtkScore.new;

// add the buffer to the score
// NOTE: buffers must be added to the score for the CtkSynthDef to access!
score.add(buffer);


// EXAMPLE 1
//
// original duration
// tune freq and refFreq to sampled buffer frequency
// D5 = 587.330 Hz
score.add(synthDef.note(starttime: 0.1, duration: buffer.duration).amp_(6.dbamp).dur_(buffer.duration).buffer_(buffer).freq_(587.330).refFreq_(587.330));


// // EXAMPLE 2
// //
// // stretch to 30 sec
// // tune grainFreq and wavFreq to sampled buffer frequency
// // D5 = 587.330 Hz
// score.add(synthDef.note(starttime: 0.1, duration: 30.0).amp_(6.dbamp).dur_(30.0).buffer_(buffer).freq_(587.330).refFreq_(587.330));


/*

Now, it turns out that in setting up this pitch synchronous granular synthesis for time-stretching, we also get the added benefit that we can do pitch synchronous pitch-shifting, too!

*/


// // EXAMPLES 3, 4, 5, 6
// //
// // play a scale, with original duration:
// myFreqs = 587.330 * [1/1, 9/8, 5/4, 4/3, 3/2, 5/3, 15/8, 2/1];
//
// // // or down an octave!!
// myFreqs = 2**(-1) * myFreqs;
//
// // // or down two octaves!!
// // // ... kinda stops sounding like a flute...
// myFreqs = 2**(-2) * myFreqs;
//
// // or up an octave!! -- we hear some artefacts....
// myFreqs = 2**(1) * myFreqs; 
//
// myFreqs.size.do({ arg i;
// 	score.add(
// 		synthDef.note(starttime: 0.1 + (i * buffer.duration), duration: buffer.duration)
// 		.amp_(6.dbamp)
// 		.dur_(buffer.duration)
// 		.buffer_(buffer)
// 		.freq_(myFreqs.at(i))
// 		.refFreq_(587.330)
// 	)
// });


// // EXAMPLE 7
// //
// // original duration
// // tune grainFreq and wavFreq to sampled buffer frequency
// // D5 = 587.330 Hz
//
// // resample waveform / shift formant structure!!
// myRatios = 2**[0.0, -0.5, -1.0, -1.5, -2.0, -2.5, -3];
//
// myRatios.size.do({ arg i;
// 	score.add(
// 		synthDef.note(starttime: 0.1 + (i * buffer.duration), duration: buffer.duration)
// 		.amp_(6.dbamp)
// 		.dur_(buffer.duration)
// 		.buffer_(buffer)
// 		.freq_(587.330)
// 		.refFreq_(587.330)
// 		.wavRatio_(myRatios.at(i))
// 	)
// });


// // EXAMPLE 8
// //
// // original duration
// // tune grainFreq and wavFreq to sampled buffer frequency
// // D5 = 587.330 Hz
//
// // resample waveform / shift formant structure!!
// myRatios = 2**[0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3];
//
// myRatios.size.do({ arg i;
// 	score.add(
// 		synthDef.note(starttime: 0.1 + (i * buffer.duration), duration: buffer.duration)
// 		.amp_(6.dbamp)
// 		.dur_(buffer.duration)
// 		.buffer_(buffer)
// 		.freq_(587.330)
// 		.refFreq_(587.330)
// 		.wavRatio_(myRatios.at(i))
// 	)
// });


// EXAMPLES 8, 9

// // chorus...
// myFreqs = 587.330 + Array.fill(6, { 5.0.rand2 });

// chord, chorus
// (nice!)
// myFreqs = 587.330 * [ 1/2, 1, 5/4, 3/2];
// myFreqs = myFreqs.collect({ arg freq;
// 	freq + Array.fill(3, { 5.0.rand2 })
// });
// myFreqs = myFreqs.flatten;

// myFreqs.size.do({ arg i;
// 	score.add(
// 		synthDef.note(starttime: 0.0, duration: buffer.duration)
// 		.amp_(-3.dbamp)
// 		.dur_(buffer.duration)
// 		.buffer_(buffer)
// 		.freq_(myFreqs.at(i))
// 		.refFreq_(587.330)
// 		.panPos_(1.0.rand2)
// 	)
// });


// write the soundfile out to disk
score.write("testCTK.wav".resolveRelative, headerFormat: 'WAV', sampleRate: s.sampleRate, options: ServerOptions.new.numOutputBusChannels_(2));
~path = "testCTK.wav".resolveRelative;
{SFPlayer(~path).gui}.defer(1);
)
SFPlayer("~/Desktop/testCTK.wav".standardizePath).gui;



/*

So... as with our previous exploration of synchronous granular synthesis, what we're hearing is that the fundament frequency is determined by the rate (frequency) at which grains are generated. That's how the major scale was generated. The final example above, illustrates what happens when the resampling ratio is changed.

The 'short answer' is that pitch synchronous granular synthesis can be used to maintain the formant structure of the source waveform, which means that fundamental pitch can be changed without changing the character of the source timbre. Similarly, when the waveform resampling ratio changes, the formant structure changes.

It should be noted, that for PSGS to work correctly (change pitch), the input sound must have a fundamental pitch! If it doesn't, our target pitch can't be guarenteed. (May be interesting, though!)

----
Something we haven't done is place envelopes on the various parameters... as you'll recognise from working with Granular Synthesis last quarter, adding continuously varying envelopes is how we can easily generate very interesting outcomes!!

*/

// EXERCISE: make it stereo!
// EXERCISE: explore the parameters of pitch synchronous granular synthesis (psgs)
// EXERCISE: try a different waveform
// EXERCISE: add vibrato and / or tremelo
// EXERCISE: add randomisation to the various parameters
// EXERCISE: adjust various parameters with Envelopes!


/*

We haven't looked at Asynchronous Granular Synthesis (AGS) here, but the basic algorithm for sampled waveforms uses the above architecture. How would we change / design an algorithm to implement "Time-shuffling" / "Brassage"? Review the AGS algorithms from DXARTS 461...

*/

// EXERCISE: implement AGS using GrainBuf!





//--------------------



// quit:
s.quit;




/*

Joseph Anderson, University of Washington, 2014-2015

*/