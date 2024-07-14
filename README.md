# base64
Learning zig while creating small program. `Base64 (standard)` and `Base64url (URL- and filename-safe standard)` Base64 (RFC 4648) implementation. Prints encoded/decoded file to stdout. Encoding standard (whether urlsafe or not) printed to stderr.

You can redirect the stdout to a new file to write the result.
```bash
base64 -e README.md > encoded_not_urlsafe.txt
base64 -d encoded_not_urlsafe.txt > README_decoded.md
```

![](demo.gif)

# Usage

Encode:

`base64 -e <file>`

Decode:

`base64 -d <file>`

You can select whether urlsafe or not with `urlsafe` environment variable.
For example:

With urlsafe: `urlsafe=1 base64 -e <file>`

With standard: `base64 -e <file>`

# LICENSE

MIT
