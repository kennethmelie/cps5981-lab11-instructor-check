# deployed/ - what is actually running

These files are an export of the configuration currently running on the lab target.
Nobody declares this folder; it is what an engineer would see in the console.

Editing a file here in the GitHub web editor is the lab's stand-in for a **console change**:
a fix made directly in production, outside the template. The `drift-check` workflow compares
this folder with the state declared in `iac/local/` and reports every divergence.
