# base64
Learning zig while creating small program. Standard Base64 (RFC 4648) implementation. Prints encoded/decoded file to stdout.

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
