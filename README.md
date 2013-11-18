dutils
======

Utilities for the D programming languages.

Short description of utilities:

1) Unique

A struct that uniquely owns a GC-allocated resource - an Object or an array. Features:

- automatic deletion
- prevents copying, while allows moving
- can be released as an immutable object
- can be moved to another thread via `send`
