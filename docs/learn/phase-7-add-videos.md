# Learning guide: Phase 7, adding videos by hand

This guide explains how TakeTray adds videos you pick yourself: friends' WhatsApp and Quick Share videos, clips from any shooting device, and, when TakeTray can't see all your videos, Android's photo picker (Manual mode).

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-111 (the owner's rulings), so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-111.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. The bridge: folder pages and the photo picker (Task 2)
3. Adding by hand, and Undo (Task 3)
4. Picked clips get pictures, verification and a grant clean-up (Task 4)
5. The folder browser (Task 5)
6. Manual mode (Task 6)
7. On the S24 (Task 7)
