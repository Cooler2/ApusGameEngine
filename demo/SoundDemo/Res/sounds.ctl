# ---------------------------------------------- #
#        Sounds and music definitions            #
#                                                #
# ����� ��������� �����-���� ����, �������       #
# ��������� ��� �������� none. ����� ���������   #
# ��������� ������ �� ���� ������� ���������     #
# ��������� ������� ��������. ����� ���� �����   #
# ������������� ���������� �� �������� ��������� #
# ---------------------------------------------- #

$Section Settings
  ; ����� ������ ��������� ��������������
  PreloadSamples        "sample.ogg"
$EndOfSection


$Section Music
  $Section TestOGG
    File     "music.ogg"
    volume   50
  $EndOfSection

  $Section TestMP3
    File     "musicLow.mp3"
    volume   50
    loop     OFF
  $EndOfSection

  $Section TestMOD
    File     "x-tag.mod"
    volume   50
  $EndOfSection

$EndOfSection


$Section SoundEvents
  ; Format: EventName  "filename,vol=xx,pan=yy"
  Sample    "sample.ogg"
  Low       "sampleLow.ogg"
  Stereo    "sampleStereo.ogg"
  Wav       "sampleWav.wav"
  sampleQuiet "sample.ogg,vol=30"
  sampleLeft  "sample.ogg,pan=-90"
$EndOfSection
