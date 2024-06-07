![Retro Logo](https://user-images.githubusercontent.com/60364512/228030301-f2139d22-48da-412b-9862-8f72e471e89c.png#gh-dark-mode-only)

![Retro Logo](https://user-images.githubusercontent.com/60364512/228030177-6b7a51f2-fe24-4ce4-8235-8d35f2526250.png#gh-light-mode-only)
An OTR / O2R generation tool.

## What is Retro?

Retro is a modding tool for games using the OTR file format. Currently only [Ship of Harkinian](https://github.com/HarbourMasters/Shipwright) uses this format.

All game assets are contained within an OTR file, the system can also recognize patch OTRs, placed in a `mods/` folder, which will replace any assets with the ones found in the patch OTR.

You can download the latest build from [here](https://github.com/HarbourMasters64/retro/releases/latest).

## Custom Textures

- Select `Create OTR`
- Select `Replace Textures`
- Follow the in-app instructions for getting set up.

Once you have your textures extracted, enter that folder, find the textures you want to replace, and replace them. Do not worry about the textures you don't want to change, Retro only puts the modified assets into the patch OTR.

Once you've modified your desired textures, go back into Retro and now that you have a texture replacement folder, select the `OOT` folder inside of it.

Make sure to enable the `Prepend 'alt/'` option, this will allow quick switching between modified assets and vanilla assets with the ingame checkbox.

Please give it a few minutes to parse all of your textures, with larger packs with a lot of high resolution textures this may take a while. Once it has completed, click `Stage Textures`, then `Finalize OTR`, then `Generate OTR`. Again, with very large packs this can take a long time, even on powerful systems.

It will prompt you to name your OTR file, and you can now place it inside the mods folder for your game.

## Custom Sequences

We support importing custom [Seq64](https://github.com/sauraen/seq64) files to replace the in game music and fanfares (Sound effect and instrument replacement is currently not supported).

First you will need to prepare a folder with the desired sequences. Every sequence requires two files with the same name and different extensions - a `.seq` Seq64 file and a `.meta` plaintext file. These files can be categorically nested in folders if desired, - Retro will recursively search each subfolder it finds.

The `.meta` file requires two lines - the first line is the name that will be displayed in the SFX editor, and the second line is the instrument set number in `base16` format. For example, if there is a sequence file `Foo.seq` then you need a meta file `Foo.meta` that could contain:
```
Awesome Name
C
```

- Select Create OTR
- Select `Custom Sequences`
- `Stage Files`
- `Finalize OTR`
- Place the OTR file this generates inside of your `mods/` folder.

## Custom Models

To edit/add custom models you will need a few additional programs/files

- [The Zelda OoT Decomp setup post asset extraction](https://github.com/zeldaret/oot)
- Blender v3.2 or above, version 3.3.5 is suggested.
- [The HarbourMasters fork of fast64 blender plugin](https://github.com/HarbourMasters/fast64) When using this fork DO NOT update from inside of Blender, it will revert Fast64 to the main branch if you do and you will be unable to properly export models.

Once all of these are setup, open Blender and enable the fast64 plugin, then next to the viewport axis control visual you should see a small arrow pointing left, click and drag that to the left to display the fast64 settings.

Under the fast64 tab set the Fast3D Global Settings set the Game to `OOT`, now a additional tab labeled OOT should display.

Under the OOT tab make sure to set the `Decomp Path` to point to the folder containing your Decomp files (the folder containing assets, baserom, build and other files/folders)

Now that the setup is done, there are a few general things to keep in mind when working on any kind of model.

All materials made must be `Fast3D Materials`, you can either convert the existing Principled BSDF materials to Fast3D under the Fast64 tab, or make new materials by pressing `Create Fast3D Material` in the Materials tab, set the appropriate preset to whatever type of material you need to make. (Solid, Texture, Transparent and so on)

If you want to use a texture larger than 32x32 for a material, assign a smaller texture that is 32x32 or below that fits the same aspect ratio and after exporting and generating the .otr file for that mod, extract the textures from that mod with Retro, replace the texture with the bigger size, and generate a new .otr file to be loaded after the model is loaded.

For custom eye and mouth texture animations, we will use Adult Link as an example in this tutorial. We will be using this list (these are found inside "object_link_boy.c"):
    eyes:
        `gLinkAdultEyesOpenTex, gLinkAdultEyesHalfTex, gLinkAdultEyesClosedfTex, gLinkAdultEyesRollLeftTex,`
        `gLinkAdultEyesRollRightTex, gLinkAdultEyesShockTex, gLinkAdultEyesUnk1Tex, gLinkAdultEyesUnk2Tex`
    mouth:
        `gLinkAdultMouth1Tex, gLinkAdultMouth2Tex, gLinkAdultMouth3Tex, gLinkAdultMouth4Tex`
1) Rename the default eye texture png (eye open, no expression) the same as the first name in the "eyes" list above (gLinkAdultEyesOpenTex.)
2) Create a new f3d material and rename that material to "gLinkAdultEyesOpenTex" as well.
3) Choose "Oot Shaded Texture" for the preset and select the PNG texture you renamed in step 1.
4) change color index to RGBA-16.
5) For the other eye textures and mouth textures repeat the same process from step 1.

After you are done with that, go to the default eye material (the material that was already there before you started creating the new f3d materials for the eyes) and enable "Use Texture Reference" then set the texture size to `0x08000000`. scroll down until you see "OOT FlipBook Properties" and under "Array Name" click on the minus sign for all textures. Afterward, uncheck "Export Flipbook Textures 0" and repeat the process with the default mouth material (the one created before you created the new f3d materials for the mouth.) The only difference is for the mouth, set the texture size to `0x09000000`.

    
If you are working with a model that uses a existing mesh from the decomp (such as ones that use Links body or hands) the built-in materials may require some adjustments, particularly with textures that use the Format `Color Index 8-bit` should be switched to `RGBA 16-bit` if you don't do this the texture may display incorrectly in-game.

Generally you can do two types of model replacements; ones that use a skeleton, and one that modifies a Display List(just the mesh).

For the purposes of a example we will make a simple edit to Child Link (this one is a example of a skeleton model replacement) on the import section of OOT Skeleton Exporter select the mode to be Child Link then click Import Skeleton, after awhile it should then display two Child Link models, one is for standard view the other is for LOD, we suggest deleting the LOD model as it can cause issues preventing exporting to work. If you do this, we suggest you enable "Disable LOD" in-game.

At this point you have a few options, you could edit Child Links model as it is, or replace it with a new model, either way it is very important that you make sure to weight paint it properly to the corresponding Vertex Groups or else the model may not display correctly in-game. If you for example replace Child Links head, you could make a new mesh and join it with the existing Child Link mesh and weight paint it to the appropriate groups.

When you are finished and are ready to export, under Object mode select the skeleton(In this case gLinkChildSkel) and on the Export section of OOT Skeleton Exporter do the following.

- Enable the Custom Path option
- Set the Skeleton selection as `gLinkChildSkel`
- Set the Internal Game Path selection as `objects/object_link_child`
- Set the Export Path selection to a empty folder

For Display List replacements however, you first need to know where the mesh is located, for example the Master Sword model is stored with the Adult Link object, the path for said object is `objects/object_link_boy` but to pull the Master Sword model out you will need the DL for it, which you can easily find in the header file for the object, if you open it you may spot a listing titled `gLinkAdultLeftHandHoldingMasterSwordNearDL` which is the DL for the Master Sword mesh.

Back in Blender, open a new file, make sure to point the Decomp folder path as that is not saved between projects, then go into the OOT tab, and under the Import DL section of the OOT DL Exporter, make sure `Use Custom Path` is disabled and do the following.

- Set the "DL" listing to the desired DL, in this case it is `gLinkAdultLeftHandHoldingMasterSwordNearDL`
- Set the "Object" to the path to the parent object, in this particular case it searching in the objects folder of the decomp so you only need the object name, in this case it is `object_link_boy`

Now the Master Swords model, along with Adult Links hand should show up, modifying or replacing these meshes is much easier then replacing the player models, all you need to do is either make a new mesh or put a pre-existing mesh in the tree, edit the Sword out from the old mesh, convert the hands Color Index 8-bit textures to RGBA 16-bit, merge your new mesh with the hand mesh and weight paint it to be the same as the old mesh scale it to the match up with the old mesh if desired, convert/make new fast3D textures for the new mesh, line it up with the hand.

When you are ready to export do the following.

- Go to the Fast64 tab and under the F3D Exporter set the `Name` to the DL name for the mesh, in this case it would be `gLinkAdultLeftHandHoldingMasterSwordNearDL`.
- Set the `Internal Game Path` to the objects path, including the objects folder, so in this case `objects/object_link_boy`
- Set the export path to a empty folder
- Set scale to be 1000.00, at default value it comes out tiny.
- Set `Material Write Method` to `Write All`
- Select the mesh in Object Mode, and click `Export Display List`

After you have your model exported, open Retro to generate the .otr file using these steps.
- Select Create OTR
- Select `Custom`
- Select folder containing the `objects` folder
- `Stage Files`
- `Finalize OTR`
- Place the OTR file this generates inside of your `mods/` folder.

### i18n localization rules

When adding any text to retro, be sure to make it localizable by doing the following
- Make sure that `import 'package:flutter_gen/gen_l10n/app_localizations.dart';` is properly imported in the file you're adding any kind of text.
- Make sure to also have this `final AppLocalizations i18n = AppLocalizations.of(context)!;`present in the override.
- When it's the time for you to add your text, follow this naming convention:
    - When you're adding a key in a **component**, use this: `i18n.components_myFile_keyName`
    - When you're adding a key somewhere else, use this: `i18n.myFile_keyName`
    - Add the corresponding keys in both `app_en.arb` which will contain your text.
    - When you're adding new text, please notify it so we can translate your new keys as fast as we can.
