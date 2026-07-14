import '../models/song.dart';
import '../models/song_section.dart';

/// A handful of public domain hymns bundled with the app so a brand new install
/// has something to present immediately, fully offline.
List<Song> buildSeedSongs() {
  return <Song>[
    const Song(
      id: 'seed-amazing-grace',
      title: 'Amazing Grace',
      author: 'John Newton',
      songKey: 'G',
      sections: <SongSection>[
        SongSection(label: 'Verse 1', lines: <String>[
          'Amazing grace! how sweet the sound',
          'That saved a wretch like me!',
          'I once was lost, but now am found,',
          'Was blind, but now I see.',
        ]),
        SongSection(label: 'Verse 2', lines: <String>[
          "'Twas grace that taught my heart to fear,",
          'And grace my fears relieved;',
          'How precious did that grace appear',
          'The hour I first believed!',
        ]),
        SongSection(label: 'Verse 3', lines: <String>[
          'Through many dangers, toils and snares,',
          'I have already come;',
          "'Tis grace hath brought me safe thus far,",
          'And grace will lead me home.',
        ]),
      ],
    ),
    const Song(
      id: 'seed-how-great-thou-art',
      title: 'How Great Thou Art',
      author: 'Carl Boberg / Stuart K. Hine',
      songKey: 'Bb',
      sections: <SongSection>[
        SongSection(label: 'Verse 1', lines: <String>[
          'O Lord my God, when I in awesome wonder',
          'Consider all the worlds Thy hands have made,',
          'I see the stars, I hear the rolling thunder,',
          'Thy power throughout the universe displayed.',
        ]),
        SongSection(label: 'Chorus', lines: <String>[
          'Then sings my soul, my Saviour God, to Thee,',
          'How great Thou art, how great Thou art!',
          'Then sings my soul, my Saviour God, to Thee,',
          'How great Thou art, how great Thou art!',
        ]),
      ],
    ),
    const Song(
      id: 'seed-it-is-well',
      title: 'It Is Well With My Soul',
      author: 'Horatio Spafford',
      songKey: 'C',
      sections: <SongSection>[
        SongSection(label: 'Verse 1', lines: <String>[
          'When peace like a river attendeth my way,',
          'When sorrows like sea billows roll;',
          'Whatever my lot, Thou hast taught me to say,',
          'It is well, it is well with my soul.',
        ]),
        SongSection(label: 'Chorus', lines: <String>[
          'It is well (it is well),',
          'With my soul (with my soul),',
          'It is well, it is well with my soul.',
        ]),
      ],
    ),
  ];
}
