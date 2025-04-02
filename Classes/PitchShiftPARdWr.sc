//A more flexible implementation of PitchShiftPA, separating sound capture and re-synthesis. See PitchShiftPA for details on the algorithm.

// required buffer size depends on the lowest processed frequency and highest formant ratio:
// ((SampleRate.ir * minFreq.reciprocal * maxFormantRatio) + BlockSize.ir).roundUp;
// e.g. for minFreq = 10 Hz and maxFormantRatio = 10, at 48kHz with block size of 64 we get:
// ((48000 * 10.reciprocal * 10) + 64).roundUp; // 48064.0
// i.e. a buffer of the duration of ~1s should be enough for most uses; use larger buffer for lower frequencies or higher formant ratio

// note: phase is audio rate!

PitchShiftPAWr {
	*ar { arg in, bufnum=0;
		var phase;
		phase = BufWr.ar(in, bufnum, Phasor.ar(0, 1, 0, BufFrames.kr(bufnum)));
		^phase
	}
}

PitchShiftPARd {
	*ar { arg phase=0, bufnum=0, trackingFreq = 440, synthFreq = 440, formantRatio, grainsPeriod = 2, timeDispersion;
		var out, grainDur, wavePeriod, trigger, freqPhase, grainPos;

		wavePeriod = trackingFreq.max(0.001).reciprocal;
		grainDur = grainsPeriod * wavePeriod;

		if(formantRatio.notNil, { //regular version
			freqPhase = LFSaw.ar(trackingFreq, 1).range(0, wavePeriod) + ((formantRatio.max(1) - 1) * grainDur);//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the phase
		}, { //slightly lighter version, without formant manipulation
			freqPhase = LFSaw.ar(trackingFreq, 1).range(0, wavePeriod);
		});

		grainPos = (phase / BufFrames.kr(bufnum)) - (freqPhase / BufDur.kr(bufnum)); //scaled to 0-1 for use in GrainBuf

		if(timeDispersion.isNil, {
			trigger = Impulse.ar(synthFreq);
		}, {
			trigger = Impulse.ar(synthFreq + (LFNoise0.kr(trackingFreq) * timeDispersion));
		});

		out = GrainBuf.ar(1, trigger, grainDur, bufnum, formantRatio ? 1, grainPos);

		^out;
	}
}

