# PitchShiftPA
*Phase-Aligned Pitch and Formant Shifter*

Phase Aligned Wavepacket (Re-)Synthesis (PAWS) pseudo-UGen, allowing for manipulating pitch and formant structure of the sound independently. This allows e.g. shifting pitch while maintaining the formant structure, or changing the formant without changing the pitch.

PitchShiftPA works only for single-voiced (monophonic) sounds and requires tracking of their fundamental frequency (e.g. using the Pitch UGen). Good quality of tracking is crucial for achieving good results.

The technique used is also known as Pitch Synchronous Overlap-Add synthesis (PSOLA) or Pitch-Synchronous Granular Synthesis (PSGS). This pseudo-UGen was created by Marcin Pączkowski at DXARTS at the University of Washington, and is based on Juan Pampin's and Joseph Anderson's implementation of Keith Lent's pitch shifting algorithm. It is distributed as a Quark for [SuperCollider](http://supercollider.github.io/).

References:
* Keith Lent, "An Efficient Method for Pitch Shifting Digitally Sampled Sounds", Computer Music Journal Vol. 13, No. 4 (Winter, 1989), pp. 65-71. Available online: https://www.jstor.org/stable/3679554
* DXARTS: https://dxarts.washington.edu/
* Juan Pampin: https://dxarts.washington.edu/people/juan-pampin
* Joseph Anderson: https://dxarts.washington.edu/people/joseph-anderson
* wave packet: https://en.wikipedia.org/wiki/Wave_packet
