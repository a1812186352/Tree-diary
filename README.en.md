# Doodle Tree Diary（绘木小札）

[中文](README.md) | [English](README.en.md)

## About the project

A magical storybook. A tree nurtured by sunlight and rain…

**Doodle Tree Diary（绘木小札）** invites you to spend time with nature. Gather sunlight and water, choose how the branches grow, and guide a small sapling into the tree you imagine. Protect its trunk and welcome animal friends who will help defend it against pests at night. Using mostly mouse movement, clicks, and dragging, place branch stickers to tell your tree’s own story of growth.
Each page brings a new day. Spend limited resources on growth during the day, welcome animal companions at dusk, and let them help defend the tree against pests at night. Newly placed branches mature after the page turns, so today's choices determine where you can grow tomorrow. The current demo lasts six days: keep at least one heart through the final night to win.

- **A storybook presentation:** a book cover, opening video, illustrated story pages, and page-turn transitions.
- **Branch placement:** drag branches and aim with the mouse, balancing available buds, resources, and space.
- **Animal companions:** ground companions and birds handle different types of pests.
- **An adjustable view:** pan and zoom to follow the tree as it grows.

[Global Game Jam project page](https://globalgamejam.org/games/2026/huimuxiaozhadoodle-tree-diary-6) · [Download releases](https://github.com/a1812186352/Tree-diary/releases)

This guide describes the current Godot demo. The game interface currently uses Chinese; this English guide includes translations of the main buttons.

## Credits

Jammers listed on the Global Game Jam project page: **Yujiacheng91** and **归梦**.

The project introduction is adapted from that page. The gameplay guide describes the current version in this repository.
## Download and launch

### Windows players

The Windows release is a **64-bit portable build**. You do not need to install Godot.

1. Visit [Releases](https://github.com/a1812186352/Tree-diary/releases) and look for a Windows game download. If no build is available, use the source instructions below. **Code → Download ZIP** downloads source code, not a playable installation package.
2. Download and fully extract the release archive into a folder.
3. Keep these two files together, then double-click the EXE:

```text
Doodle Tree Diary(winx86).exe
Doodle Tree Diary(winx86).pck
```

Despite the `winx86` label in the filename, the current executable is **x86_64 (64-bit)**. Keep the EXE and PCK filename stems identical. Do not copy only the EXE or launch it from inside the archive.

> The current executable is not digitally signed. If a security warning appears, verify the download source and the exact message. If antivirus software reports a named threat, send the author the antivirus name, detection name, and a screenshot rather than disabling protection.

### Run from source

1. Clone this repository, or select **Code → Download ZIP** and extract it:

   ```bash
   git clone https://github.com/a1812186352/Tree-diary.git
   ```

2. Open **Godot 4.7.2**, the version used by the current project. Select **Import** in the Project Manager and choose `project.godot`.
3. Wait for the initial asset import to finish, then press **F5** to run the full game.

The main entry is `scenes/opening/book_opening.tscn`. The project uses the Forward Plus renderer, so your hardware and graphics drivers must support it. Godot AI, MCP, and other development plugins are not required.

## How to play

### Open the book

- Click **开始阅读** (Start reading) on the cover, or press **Enter / Space**.
- Click **跳过开篇** (Skip opening) to skip the video and continue to the story pages.
- Advance the story with the next-page button or **Enter / Space / Right Arrow**. On the final page, **进入第一天** (Enter day one) starts the game.

### Help the tree survive six days

You start with **3 hearts**. Survive the final night with at least one heart to win; losing all hearts ends the run.

- **Day — 40 seconds:** click sunlight and water to collect them, then drag branches from the bottom-right tray to free buds on the tree.
- **Dusk — 10 seconds:** watch companions arrive. Acorn and feather omens produced by growth are associated with later animal companions.
- **Night — 30 seconds:** companions defend automatically. Ground companions deal with ground pests; birds deal with flying pests.
- **A new page:** newly placed branches mature and their buds become available for further growth.

Each day provides **6 sunlight and 6 water**. Unspent resources do not carry over. A one-, two-, or three-bud branch costs **1, 2, or 3 of each resource**, respectively. Each bud can hold one child branch. Unused buds remain available on later days.

## Controls

| Action | Input |
| --- | --- |
| Collect sunlight or water | Left-click the resource |
| Place a branch | Hold the left mouse button on a tray branch, drag near a free bud, then release |
| Aim a branch | Move the mouse while dragging; the branch points toward the cursor around the snapped bud |
| Cancel a branch preview | Right-click |
| Recover an immature branch placed that day | Right-click near its connection point to remove it and refund resources; mature branches cannot be removed |
| Zoom | Mouse wheel, centered on the cursor |
| Pan | Hold the middle mouse button and drag |
| Reset the view | Double-click the middle mouse button |
| Pause / close the menu | Esc, or use the buttons at the top of the screen |
| Restart | Use the menu or the **再种一棵** (Grow another tree) button on the ending screen |

A green-tinted preview indicates a valid placement; a red-tinted preview indicates an invalid one. If a branch cannot be placed, move closer to a free bud, adjust its direction, avoid other branches, or collect more resources.

## Troubleshooting

**The EXE does not open the game.**  
Make sure the archive is fully extracted and the matching EXE and PCK are in the same folder. Replace both files when updating.

**There is no EXE in the repository ZIP.**  
The repository contains source code. EXE/PCK exports are excluded by `.gitignore`. Download a playable build from Releases or run the source in Godot.

**I cannot attach another branch to the one I just placed.**  
Its buds become available after it matures at the next page turn.

**I lost sight of the tree or resources after moving the camera.**  
Double-click the middle mouse button to reset the view. Resources stay at their world positions after spawning; moving the camera does not refresh them.

## Project entry points

- `project.godot` — Godot project file.
- `scenes/opening/book_opening.tscn` — full game entry.
- `scenes/main.tscn` — core gameplay scene.
- `config/opening.tres` — book cover, video, and opening settings.
- `config/story.tres` — story-page configuration.
- `config/mvp.tres` — gameplay timing, assets, and parameters.

Generated `.godot/` caches, release builds, local tools, and credentials are excluded from version control. Asset `.import` settings and script `.uid` files are kept.
