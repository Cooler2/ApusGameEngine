# ---------------------------------------------- #
#        Sounds and music definitions            #
# ---------------------------------------------- #

Settings {
  # samples to load in advance: a list of files, ALL or NONE
  PreloadSamples = "sample.ogg"
}

Music {
  TestOGG {
    File   = "music.ogg"
    volume = 50
    loop   = on
  }

  TestMP3 {
    File   = "musicLow.mp3"
    volume = 50
    loop   = off
  }

  TestLoop {
    File    = "loop.wav"
    volume  = 50
    loop    = on
    # loop start in samples: the 0.5 s intro plays once
    loopPos = 22050
  }

  TestLoopTime {
    File     = "loop.wav"
    volume   = 50
    loop     = on
    # the same loop start in seconds
    loopTime = 0.5
  }

  TestLoopBad {
    File     = "loop.wav"
    volume   = 50
    loop     = on
    # the loop start is 2 ms late: the phase jumps, a click every second
    loopTime = 0.502
  }

  TestMOD { File = "x-tag.mod", volume = 50 }
}

SoundEvents {
  # an event is "file,vol=xx,pan=yy" or { file = "...", vol = xx, pan = yy }
  Sample      = "sample.ogg"
  Low         = "sampleLow.ogg"
  Stereo      = "sampleStereo.ogg"
  Wav         = "sampleWav.wav"
  sampleQuiet = { file = "sample.ogg", vol = 30 }
  sampleLeft  = "sample.ogg,pan=-90"
}
