# Learning guide: Phase 5, tagging

This guide explains how TakeTray turns a day's clips into sorted reels: the To tag tab with its scenes, the tag player (one tap per clip), Skip, Skip all and the Skipped list, and how every tag and skip can be undone.

Every snippet is real code from this repository. You don't need to know Flutter well to follow it; basic programming knowledge is enough.

## How to read this guide

- **The big picture first.** Phase 3 found your new videos and put them in To tag. Phase 4 built the reels. Phase 5 joins the two:
  - a **scene** is a run of clips shot close together (less than 10 minutes apart, on the same day);
  - **tagging** puts a clip into one or more reels, and takes it out of To tag;
  - **skipping** moves a clip to the Skipped list, where it can be restored;
  - every tag, skip and restore returns an **undo record**, so the message at the bottom can offer **Undo**.
- **Order.** The sections follow the order the phase was built, from Section 2 on. Step 1 was the plan and decision D-91 (what Phase 5 builds now and what waits), so it has no section here.
  - the design-system pieces (2, 3);
  - the data: skip, skip all, restore and undo (4);
  - the rules: scenes and the order of clips (5);
  - the tag player's logic (6) and screen (7);
  - To tag (8) and Skipped (9);
  - the proof on the phone (10).
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-91. "Spec §8.4" is a section of `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`.
- **Commands.** Run them from the repository root, through the wrappers in `tool/` (`tool/flutter`, `tool/check`). Run a single test file from `app/` (`cd app && ../tool/flutter test test/...`).
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Player chrome debts](#2-player-chrome-debts)
3. [The tag panel, done summary and info bar](#3-the-tag-panel-done-summary-and-info-bar)
4. [Skip, skip all and restore with undo](#4-skip-skip-all-and-restore-with-undo)
5. [Scenes, the tag queue and time ranges](#5-scenes-the-tag-queue-and-time-ranges)
6. [The tag session](#6-the-tag-session)
7. [The tag player screen and All done](#7-the-tag-player-screen-and-all-done)
8. [To tag with scenes, and the picker's tag mode](#8-to-tag-with-scenes-and-the-pickers-tag-mode)
9. [The Skipped list](#9-the-skipped-list)
10. [On the S24](#10-on-the-s24)

## 2. Player chrome debts

_Filled in by Task 2._

## 3. The tag panel, done summary and info bar

_Filled in by Task 3._

## 4. Skip, skip all and restore with undo

_Filled in by Task 4._

## 5. Scenes, the tag queue and time ranges

_Filled in by Task 5._

## 6. The tag session

_Filled in by Task 6._

## 7. The tag player screen and All done

_Filled in by Task 7._

## 8. To tag with scenes, and the picker's tag mode

_Filled in by Task 8._

## 9. The Skipped list

_Filled in by Task 9._

## 10. On the S24

_Filled in by Task 10._
