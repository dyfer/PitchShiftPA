//PitchShiftPA is based on formant preserving pitch-synchronous overlap-add re-synthesis, as developed by Keith Lent
//based on real-time implementation by Juan Pampin, combined with non-real-time implementation by Joseph Anderson
//pseudo-UGen by Marcin Pączkowski, using GrainBuf and a circular buffer

PitchShiftPA {
	*ar { arg in, freq = 440, pitchRatio = 1, formantRatio = 1, minFreq = 10, maxFormantRatio = 10, grainsPeriod = 2, timeDispersion;

		var out, localbuf, grainDur, wavePeriod, trigger, freqPhase, maxdelaytime, grainFreq, bufSize, delayWritePhase, grainPos;
		var absolutelyMinValue = 0.01; // used to ensure positive values before reciprocating
		var numChannels = 1;

		//multichanel expansion
		[in, freq, pitchRatio, formantRatio].do({ arg item;
			item.isKindOf(Collection).if({ numChannels = max(numChannels, item.size) });
		});

		in = in.asArray.wrapExtend(numChannels);
		freq = freq.asArray.wrapExtend(numChannels);
		pitchRatio = pitchRatio.asArray.wrapExtend(numChannels);

		minFreq = minFreq.max(absolutelyMinValue);
		maxdelaytime = minFreq.reciprocal;

		freq = freq.max(minFreq);

		wavePeriod = freq.reciprocal;
		grainDur = grainsPeriod * wavePeriod;
		grainFreq = freq * pitchRatio;

		if(formantRatio.notNil, { //regular version

			formantRatio = formantRatio.asArray.wrapExtend(numChannels);

			maxFormantRatio = maxFormantRatio.max(absolutelyMinValue);
			formantRatio = formantRatio.clip(maxFormantRatio.reciprocal, maxFormantRatio);

			bufSize = ((SampleRate.ir * maxdelaytime * maxFormantRatio) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
			freqPhase = LFSaw.ar(freq, 1).range(0, wavePeriod) + ((formantRatio.max(1) - 1) * grainDur);//phasor offset for formant shift up - in seconds; positive here since phasor is subtracted from the delayWritePhase

		}, { //slightly lighter version, without formant manipulation

			formantRatio = 1 ! numChannels;

			bufSize = ((SampleRate.ir * maxdelaytime) + (SampleRate.ir * ControlDur.ir)).roundUp; //extra padding for maximum delay time
			freqPhase = LFSaw.ar(freq, 1).range(0, wavePeriod);
		});

		localbuf = numChannels.collect({LocalBuf(bufSize, 1).clear});
		delayWritePhase = numChannels.collect({|ch| BufWr.ar(in[ch], localbuf[ch], Phasor.ar(0, 1, 0, BufFrames.kr(localbuf[ch])))});
		grainPos = (delayWritePhase / BufFrames.kr(localbuf)) - (freqPhase / BufDur.kr(localbuf)); //scaled to 0-1 for use in GrainBuf
		if(timeDispersion.isNil, {
			trigger = Impulse.ar(grainFreq);
		}, {
			trigger = Impulse.ar(grainFreq + (LFNoise0.kr(grainFreq) * timeDispersion));
		});
		out = numChannels.collect({|ch| GrainBuf.ar(1, trigger[ch], grainDur[ch], localbuf[ch], formantRatio[ch], grainPos[ch])});

		^out;
	}
}
