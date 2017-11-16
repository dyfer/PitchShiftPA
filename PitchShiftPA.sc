//PitchShiftPA is based on formant preserving pitch-synchronous overlap-add re-synthesis, as developed by Keith Lent,
//based on real-time implementation by Juan Pampin, combined with non-real-time implementation by Joseph Anderson
//pseudo-UGen by Marcin Pączkowski, using GrainBuf and a circular buffer

PitchShiftPA {
	*ar { arg in, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainsPeriod = 2;

		var out, localbuf, grainDur, wavePeriod, trigger, freqPhase, delaytime, maxdelaytime, grainFreq, bufSize, delayWritePhase, grainPos;

		if(formantRatio.notNil, {

			minFreq = minFreq.max(0.001); //protect agains division by 0 further down
			maxdelaytime = minFreq.reciprocal;
			formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);
			bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
			localbuf = LocalBuf(bufSize, 1).clear;

			freq = freq.max(minFreq);

			wavePeriod = freq.reciprocal;
			grainDur = grainsPeriod * wavePeriod;
			grainFreq = freq * pitchRatio;

			trigger = Impulse.ar(grainFreq);
			freqPhase = LFSaw.ar(freq, 1).range(0, wavePeriod) + ((formantRatio.max(1) - 1) * grainDur);//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase
			delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
			grainPos = (delayWritePhase / BufFrames.kr(localbuf)) - (freqPhase / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
			out = GrainBuf.ar(1, trigger, grainDur, localbuf, formantRatio, grainPos);

		}, { //slightly lighter version

			minFreq = minFreq.max(0.001); //protect agains division by 0 further down
			maxdelaytime = minFreq.reciprocal;
			bufSize = ((SampleRate.ir * maxdelaytime) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
			localbuf = LocalBuf(bufSize, 1).clear;

			freq = freq.max(minFreq);

			wavePeriod = freq.reciprocal;
			grainDur = grainsPeriod * wavePeriod;
			grainFreq = freq * pitchRatio;

			trigger = Impulse.ar(grainFreq);
			freqPhase = LFSaw.ar(freq, 1).range(0, wavePeriod);
			delayWritePhase = BufWr.ar(in, localbuf, Phasor.ar(0, 1, 0, BufFrames.kr(localbuf)));
			grainPos = (delayWritePhase / BufFrames.kr(localbuf)) - (freqPhase / BufDur.kr(localbuf)); //scaled to 0-1
			out = GrainBuf.ar(1, trigger, grainDur, localbuf, 1, grainPos);
		});
		^out;
	}
}
