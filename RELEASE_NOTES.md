### Added
• Quick Edit can now crop and resize copied images before pasting them back into another app.
• OpenPaste now encrypts clipboard history at rest by default and automatically migrates existing local databases.

### Fixed
• Fixed Quick Edit image exports so resized images land on the pasteboard with the expected TIFF dimensions.
• Improved release validation reliability by hardening the app’s hosted startup and encrypted-storage end-to-end test coverage.

### Changed
• Sensitive clipboard buffers are now wiped from memory after processing to reduce exposure for secrets and other private content.
