# Demo media

Seed listing photos and profile portraits are bundled as WebP. Demo mode and Android read them from `assets/photos/` and `assets/avatars/`. The web build serves the same files from `web/demo_media/`, so a published staging app loads them at `https://homizi.netlify.app/demo_media/<file>`.

Staging rows store those public URLs in `property_photos.storage_path` and `profiles.avatar_path`. The app draws an `https` URL directly. A photo uploaded by a signed-in person is stored in the private `listing-photos` bucket or the public `avatars` bucket and is drawn from a signed or public storage URL.

These frames are Unsplash photographs. The [Unsplash License](https://unsplash.com/license) allows commercial use and does not require attribution. They are not NoBroker images.

## Interiors and exteriors

Source page: `https://unsplash.com/photos/<id>`.

| File | Unsplash photo id |
| --- | --- |
| living_01.webp | photo-1502672260266-1c1ef2d93688 |
| living_02.webp | photo-1560448204-e02f11c3d0e2 |
| living_03.webp | photo-1493809842364-78817add7ffb |
| living_04.webp | photo-1560185007-cde436f6a4d0 |
| living_05.webp | photo-1618221195710-dd6b41faaea6 |
| bed_01.webp | photo-1616594039964-ae9021a400a0 |
| bed_02.webp | photo-1615874959474-d609969a20ed |
| bed_03.webp | photo-1598928506311-c55ded91a20c |
| bed_04.webp | photo-1560185127-6ed189bf02f4 |
| kitchen_01.webp | photo-1556912173-46c336c7fd55 |
| kitchen_02.webp | photo-1556909114-f6e7ad7d3136 |
| kitchen_03.webp | photo-1600566753190-17f0baa2a6c3 |
| bath_01.webp | photo-1552321554-5fefe8c9ef14 |
| bath_02.webp | photo-1620626011761-996317b8d101 |
| exterior_01.webp | photo-1545324418-cc1a3fa10c00 |
| exterior_02.webp | photo-1600585154340-be6161a56a0c |
| exterior_03.webp | photo-1600596542815-ffad4c1539a9 |
| balcony_01.webp | photo-1600607687939-ce8a6c25118c |
| balcony_02.webp | photo-1600585154526-990dced4db0d |
| dining_01.webp | photo-1554995207-c18c203602cb |
| workspace_01.webp | photo-1522708323590-d24dbb6b0267 |

The original JPEG copies remain in `assets/photos/` next to `CREDITS.txt`. The WebP files are the ones the app and the seed URLs use.

## Portraits

Centre-cropped squares. Same license.

| File | Unsplash photo id |
| --- | --- |
| avatar_01.webp | photo-1544005313-94ddf0286df2 |
| avatar_02.webp | photo-1506794778202-cad84cf45f1d |
| avatar_03.webp | photo-1531123897727-8f129e1688ce |
| avatar_04.webp | photo-1500648767791-00dcc994a43e |
| avatar_05.webp | photo-1524504388940-b1c1722653e1 |
| avatar_06.webp | photo-1534528741775-53994a69daeb |
