# Learning guide: Phase 9A, References in the app

This guide explains how TakeTray shows and uses the links saved on a reel: the References section on the reel page, the sheet to add a link or edit its label, opening a link in its app, the link field in the reel form, the badge on Home's reel cards, and the References row and sheet on the Shooting mode card. It ends with how it was checked on a real Samsung Galaxy S24 Ultra.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-153, so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-153.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Link rules, remove with Undo, a reel with its link](#2-link-rules-remove-with-undo-a-reel-with-its-link)
3. [Opening a link and the source apps' icons](#3-opening-a-link-and-the-source-apps-icons)
4. [The reference card's menu and large text](#4-the-reference-cards-menu-and-large-text)
5. [The Add / edit reference sheet](#5-the-add--edit-reference-sheet)
6. [The References section and the Home badge](#6-the-references-section-and-the-home-badge)
7. [The reel form's link field](#7-the-reel-forms-link-field)
8. [Shooting mode's References](#8-shooting-modes-references)
9. [On the S24](#9-on-the-s24)
