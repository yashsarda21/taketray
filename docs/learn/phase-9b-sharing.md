# Learning guide: Phase 9B, Sharing into TakeTray

This guide explains how a link shared from Instagram (or any app) reaches TakeTray: the see-through share screen with its own Flutter engine, how two engines share one database, the Save reference sheet, opening the saved reel through onboarding, and the reels step that lists reels made by a share. It ends with how it was checked on a real Samsung Galaxy S24 Ultra.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-162, so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-162.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [The share entry](#2-the-share-entry)
3. [Two engines, one database](#3-two-engines-one-database)
4. [Open reel, held through onboarding](#4-open-reel-held-through-onboarding)
5. [The Save reference sheet](#5-the-save-reference-sheet)
6. [The share screen over the sharing app](#6-the-share-screen-over-the-sharing-app)
7. [Onboarding: reels made by a share](#7-onboarding-reels-made-by-a-share)
8. [Patrol flows](#8-patrol-flows)
9. [On the S24](#9-on-the-s24)
