#!/bin/bash
# Mix VO + music + SFX onto the silent film. Times match film.js.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUD="$ROOT/media/audio"
SILENT="${1:-$ROOT/media/raw/film_silent.mp4}"
OUT="$ROOT/media/demo.mp4"

# adelay is milliseconds
# vo1 0.55s, vo2 4.55s, vo3 11.40s, vo4 24.30s, vo5 28.90s
ffmpeg -y \
  -i "$SILENT" \
  -i "$AUD/music.wav" \
  -i "$AUD/vo1.wav" \
  -i "$AUD/vo2.wav" \
  -i "$AUD/vo3.wav" \
  -i "$AUD/vo4.wav" \
  -i "$AUD/vo5.wav" \
  -i "$AUD/whoosh.wav" \
  -i "$AUD/click.wav" \
  -i "$AUD/click_soft.wav" \
  -i "$AUD/block.wav" \
  -i "$AUD/chime.wav" \
  -filter_complex "\
    [1:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,volume=0.18,apad=pad_dur=4,afade=t=in:d=1.4,afade=t=out:st=32.6:d=2.2[bed];\
    [2:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=550|550,volume=1.15[v1];\
    [3:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=4550|4550,volume=1.15[v2];\
    [4:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=11400|11400,volume=1.15[v3];\
    [5:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=24300|24300,volume=1.15[v4];\
    [6:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=28900|28900,volume=1.15[v5];\
    [7:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=4000|4000,volume=0.45[w1];\
    [7:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=11050|11050,volume=0.42[w2];\
    [7:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=17150|17150,volume=0.42[w3];\
    [7:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=24050|24050,volume=0.42[w4];\
    [8:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=5150|5150,volume=0.55[c1];\
    [8:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=7450|7450,volume=0.55[c2];\
    [9:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=5310|5310,volume=0.35[s1];\
    [9:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=7610|7610,volume=0.35[s2];\
    [10:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=5320|5320,volume=0.4[b1];\
    [11:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,adelay=29200|29200,volume=0.55[ch];\
    [bed][v1][v2][v3][v4][v5][w1][w2][w3][w4][c1][c2][s1][s2][b1][ch]amix=inputs=16:dropout_transition=0:normalize=0:duration=first,alimiter=limit=0.95[a]\
  " \
  -map 0:v -map "[a]" \
  -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
  -c:a aac -b:a 192k \
  -shortest -movflags +faststart \
  "$OUT"

echo "wrote $OUT"
ffprobe -v error -show_entries format=duration,size -of default "$OUT"
