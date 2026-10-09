# Clean Unreal Templates

CleanUnrealTemplates is a simple tool that provides cleaner files when creating new C++ classes in Unreal.

### Examples for a new Character:

<table>
  <tr>
    <td colspan="2"><h3>Default Templates:</h3></td>
  </tr>
  <tr>
    <td valign="top" width="50%" height="50">
      <img width="988" height="576" alt="DefaultMyCharacterCPP" src="https://github.com/user-attachments/assets/fb92b18a-d006-4d93-adb0-4bafec5ad524" />
    </td>
    <td valign="top" width="50%" height="50">
      <img width="802" height="495" alt="DefaultMyCharacterH" src="https://github.com/user-attachments/assets/050799bb-cc5a-42c0-ba66-366aed7e4b93" />
    </td>
  </tr>
  <tr>
    <td colspan="2"><h3>Clean Templates:</h3></td>
  </tr>
  <tr>
    <td valign="top" width="50%" height="50">
      <img width="744" height="374" alt="CleanMyCharacterCPP" src="https://github.com/user-attachments/assets/5ff06fb2-c3c5-439b-8e88-11b117f25861" />
    </td>
    <td valign="top" width="50%" height="50">
      <img width="823" height="339" alt="CleanMyCharacterH" src="https://github.com/user-attachments/assets/13ba5d57-4728-4188-bddf-0a38604b7f78" />
    </td>
  </tr>
</table>

## Description

This program replaces the default .template files installed with those located in the **CleanTemplates** folder. **CleanTemplates** files were edited using a set of rules such as removing unnecessary comments or blank lines, written inside the **ApplyRulesScript.ps1** which you are free to modify.

## Versions

- CleanUneralTemplates release version : **1.0**
- Current supported Unreal version : **Unreal 5.8**
- Current edited classes :
  - Actor
  - ActorComponent
  - Character
  - Empty
  - Interface
  - Pawn
  - UObject

## Usage

Simply run the **CleanUnrealTemplates.bat** program and select the Unreal **Templates** folder installed on your PC. You will be given the option to copy the existing .template files into a Backup folder before overwriting them.
