# Piano Transcriber

Piano Transcriber is an iOS app that given an audio file with piano music will generate midi events corresponding to what is being played.
The app looks like this:

<p align="center">
  <img src="screenshots/demo.gif" alt="Demo" width="30%" />
  <img src="screenshots/home.png" alt="Home" width="30%" />
  <img src="screenshots/playing.png" alt="Playing" width="30%" />
</p>

Piano Transcriber is fully open source, and all processing is happening on the device itself, and nothing is being sent to a remote server.

The model powering Piano Transcriber can be found at [audio-to-midi](https://github.com/kasper0406/audio-to-midi).

In order to build Piano Transcriber, it needs a framework produced by the audio-to-midi project, to get the actual midi events form the model output. Currently this is palces in this repository in the `model_utils` folder as a static build. If you want to modify this logic, the code is found at the [Rust plugins for audio-to-midi](https://github.com/kasper0406/audio-to-midi/tree/main/rust-plugins).
