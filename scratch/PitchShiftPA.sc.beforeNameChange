//PSGPitchShifter based on formant preserving pitch-synchronous overlap-add re-synthesis, as developed by Keith Lent,
//based on real-time implementation by Juan Pampin, combined with non-real-time implementation by Jo Anderson
//pseudo-UGen by Marcin Pączkowski

PSGPitchShiftDL { //original Juan's implementation, with fix for crashing when freq = 0
	*ar { | in, freq = 440, ratio = 1, minFreq = 30// , grainPeriods = 2, maxOctaves = 2
		|

		var out, grainSig, localbuf, numDelays, grainDur, wavePeriod, trigger, phasor, delaytime, delays, maxdelaytime, grainFreq, bufSize, delayWritePhase;
		var grainPeriods = 2, maxOctaves = 2;
		minFreq = minFreq.max(0.001);

		maxdelaytime = minFreq.reciprocal;
		numDelays = grainPeriods * (2**maxOctaves);

		freq = freq.max(minFreq);

		wavePeriod = 1.0/freq;
		grainDur = grainPeriods * wavePeriod;
		grainFreq = freq * ratio;

		trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays);
		phasor = LFSaw.ar(freq, 1).range(0, wavePeriod);
		delaytime = Latch.ar(phasor, trigger);
		CheckBadValues.ar(delaytime, 0, 1);
		delays = DelayC.ar(in, maxdelaytime, delaytime);
		out = Mix(GrainIn.ar(1, trigger, grainDur, delays));
		^out;
	}
}

PSGPitchShiftMT { //replace superfluous delay lines with a multitap implementation
	*ar { | in, freq = 440, ratio = 1, minFreq = 30// grainPeriods = 2, maxOctaves = 2
		|

		var out, grainSig, localbuf, numDelays, grainDur, wavePeriod, trigger, phasor, delaytime, delays, maxdelaytime, grainFreq, bufSize, delayWritePhase;
		var grainPeriods = 2, maxOctaves = 2;
		minFreq = minFreq.max(0.001);

		maxdelaytime = minFreq.reciprocal;
		numDelays = grainPeriods * (2**maxOctaves);
		// numDelays = 2 * (2**2);
		bufSize = ((SampleRate.ir * maxdelaytime) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
		// bufSize = SampleRate.ir;
		localbuf = LocalBuf(bufSize, 1).clear;

		freq = freq.max(minFreq);

		wavePeriod = freq.reciprocal;
		grainDur = grainPeriods * wavePeriod;
		grainFreq = freq * ratio;

		trigger = Impulse.ar(grainFreq / numDelays, Array.series(numDelays)/numDelays);
		phasor = LFSaw.ar(freq, 1).range(0, wavePeriod);
		delaytime = Latch.ar(phasor, trigger);
		// CheckBadValues.ar(delaytime, 0, 1);
		delayWritePhase = DelTapWr.ar(localbuf, in);
		delays = DelTapRd.ar(localbuf, delayWritePhase, delaytime, 4); //multiple delays from single buffer
		out = Mix(GrainIn.ar(1, trigger, grainDur, delays));
		^out;
	}
}

PSGPitchShift { //GrainBuf implementation using a circular buffer
	*ar { | in, freq = 440, pitchRatio = 1, minFreq = 30, grainPeriods = 2 |

		var out, grainSig, localbuf, grainDur, wavePeriod, trigger, freqPhase, delaytime, maxdelaytime, grainFreq, bufSize, delayWritePhase, grainPos;

		minFreq = minFreq.max(0.001); //protect agains division by 0 further down
		maxdelaytime = minFreq.reciprocal;
		bufSize = ((SampleRate.ir * maxdelaytime) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
		localbuf = LocalBuf(bufSize, 1).clear;

		freq = freq.max(minFreq);

		// wavePeriod = freq.reciprocal;
		wavePeriod = freq.reciprocal;
		grainDur = grainPeriods * wavePeriod;
		// grainDur = grainPeriods * wavePeriod * pitchRatio.max(0.001).reciprocal; //Marcin: adjust grainDur to achieve the same overlap for the full range of pitchRatio... doesn't work quite right for ratios 0.5, 0.25 etc...
		grainFreq = freq * pitchRatio;

		trigger = Impulse.ar(grainFreq);
		freqPhase = LFSaw.ar(freq, 1).range(0, wavePeriod);
		// CheckBadValues.ar(delaytime, 0, 1);
		delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
		grainPos = (delayWritePhase / BufFrames.kr(localbuf)) - (freqPhase / BufDur.kr(localbuf)); //scaled to 0-1
		out = GrainBuf.ar(1, trigger, grainDur, localbuf, 1, grainPos);
		^out;
	}
}

PSGPitchFormantShift { //GrainBuf implementation using a circular buffer - with formant shift
	*ar { | in, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainPeriods = 2|

		var out, grainSig, localbuf, grainDur, wavePeriod, trigger, freqPhase, grainPos, delaytime, maxdelaytime, grainFreq, bufSize, delayWritePhase;

		minFreq = minFreq.max(0.001); //protect agains division by 0 further down
		maxdelaytime = minFreq.reciprocal;
		formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);
		bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
		localbuf = LocalBuf(bufSize, 1).clear;

		freq = freq.max(minFreq);

		wavePeriod = freq.reciprocal;
		grainDur = grainPeriods * wavePeriod;
		grainFreq = freq * pitchRatio;

		trigger = Impulse.ar(grainFreq);
		// freqPhase = LFSaw.ar(freq, 1).range(0, wavePeriod) + (formantRatio * wavePeriod * (formantRatio > 1));
		freqPhase = LFSaw.ar(freq, 1).range(0, wavePeriod) + ((formantRatio.max(1) - 1) * grainDur);//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase!
		// CheckBadValues.ar(delaytime, 0, 1);
		delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
		grainPos = (delayWritePhase / BufFrames.kr(localbuf)) - (freqPhase / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
		out = GrainBuf.ar(1, trigger, grainDur, localbuf, formantRatio, grainPos);
		^out;
	}
}

PSGPitchFormantShift1 { //GrainBuf implementation using a circular buffer - with formant shift and asynchronous granulation fallback
	*ar { | in, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainPeriods = 2, synchronous = 1, asyncPitchChange = 1, asyncGrainRate = 40, asyncGrainPeriods = 4, asyncTimeDispersion = 0.01, asyncPitchDispersion = 0.01|

		var out, grainSig, localbuf, grainDur, wavePeriod, trigger, freqPhase, grainPos, delaytime, maxdelaytime, grainFreq, bufSize, delayWritePhase, pitchRatioAsync;

		minFreq = minFreq.max(0.001).min(asyncGrainRate - asyncTimeDispersion); //protect agains division by 0 further down; also clip
		maxdelaytime = minFreq.reciprocal;
		formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);
		bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
		localbuf = LocalBuf(bufSize, 1).clear;

		freq = freq.max(minFreq);
		grainFreq = freq * pitchRatio;

		wavePeriod = Select.ar(synchronous, [
			K2A.ar(asyncGrainRate.max(0.001).reciprocal),
			K2A.ar(freq.reciprocal)
		]);
		grainDur = Select.ar(synchronous, [
			K2A.ar(asyncGrainPeriods),
			K2A.ar(grainPeriods)
		]) * wavePeriod;

		trigger = Impulse.ar(Select.kr(synchronous, [
			asyncGrainRate + (LFNoise0.kr * asyncGrainRate * asyncTimeDispersion),
			grainFreq
		]));

		pitchRatioAsync = TRand.ar(asyncPitchDispersion.neg, asyncPitchDispersion, trigger) + (pitchRatio * (asyncPitchChange > 0));

		freqPhase = Select.ar(synchronous, [
			((pitchRatioAsync.max(1) - 1)) * grainDur,// +  TRand.kr(0, asyncTimeDispersion, trigger),
			LFSaw.ar(freq, 1).range(0, wavePeriod) + ((formantRatio.max(1) - 1) * grainDur);//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase!
		]);//.poll;

		// CheckBadValues.ar(delaytime, 0, 1);
		formantRatio = Select.kr(synchronous, [
			Select.kr(asyncPitchChange, [
				1, //no pitch change
				pitchRatioAsync //async formant ratio <- pitch shift
			]),
			formantRatio //synchronous formant ratio
		]);

		delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)), 0);
		grainPos = (delayWritePhase / BufFrames.kr(localbuf)) - (freqPhase / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
		out = GrainBuf.ar(1, trigger, grainDur, localbuf, formantRatio, grainPos);
		^out;
	}
}