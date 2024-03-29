graphpath
=========

## Description

Graphpath generates an ASCII network diagram from the route table of a Unix/Linux router. It's a [BSDRP](https://bsdrp.net)'s tool.

## Dependecy

None: it's just a shell script using standards tools (route, arp, ifconfig on *BSD and ip on Linux).

## Examples

Here are some graphpath output:

```
[root@me]~# graphpath 10.0.11.11 10.0.12.12
+----------------------------+    +----------------------------+
| SOURCE HOST                |    | DESTINATION HOST           |
| IP:   10.0.11.11           |    | IP:  10.0.12.12            |
+----------------------------+    +----------------------------+
                  |                             |
+----------------------------+    +----------------------------+
| ROUTER TOWARDS SOURCE      |    | ROUTER TOWARDS DESTINATION |
| IP:   10.0.1.11            |    | IP:  10.0.1.12             |
| ARP:  02:01:32:38:b0:03    |    | ARP:  02:01:32:38:b0:04    |
+----------------------------+    +----------------------------+
                  |                             |
            --+---+-----------------------------+---
                  |
+----------------------------+
| IF:   bridge1              |
| MAC:  02:ab:de:8c:30:01    |
| IP:   10.0.1.1             |
| net:  10.0.11.0            |
| mask: 255.255.255.0        |
|                            |
|         THIS ROUTER        |
+----------------------------+
```

```
[root@me]~# graphpath 2001:db8:11::11 2001:db8:1::12
+---------------------------------------------------+  +---------------------------------------------------+
| SOURCE HOST                                       |  | DESTINATION HOST                                  |
| IP:   2001:db8:11::11                             |  | IP:   2001:db8:1::12                              |
|                                                   |  | NDP:  02:01:c9:01:b0:04                           |
+---------------------------------------------------+  +---------------------------------------------------+
                         |                                                  |
+---------------------------------------------------+                       |
| ROUTER TOWARDS SOURCE                             |                       |
| IP:   2001:db8:1::11                              |                       |
| NDP:  02:01:c9:01:b0:03                           |                       |
+---------------------------------------------------+                       |
                         |                                                  |
                       --+---+----------------------------------------------+---
                             |
+---------------------------------------------------+
| IF:   bridge1                                     |
| MAC:  02:de:f2:41:54:01                           |
| IP:   2001:db8:1::1                               |
| net:  2001:db8:11::                               |
| mask: ffff:ffff:ffff:ffff::                       |
|                                                   |
|                    THIS ROUTER                    |
+---------------------------------------------------+
```

```
[root@me]~# graphpath 10.0.11.11 10.0.21.21
+----------------------------+
| SOURCE HOST                |
| IP:   10.0.11.11           |
+----------------------------+
              |
+----------------------------+
| ROUTER TOWARDS SOURCE      |
| IP:   10.0.1.11            |
| ARP:  02:01:32:38:b0:03    |
+----------------------------+
              |
+----------------------------+
| IF:   bridge1              |
| MAC:  02:ab:de:8c:30:01    |
| IP:   10.0.1.1             |
| net:  10.0.11.0            |
| mask: 255.255.255.0        |
|                            |
|         THIS ROUTER        |
|                            |
| net:  10.0.21.0            |
| mask: 255.255.255.0        |
| IP:   10.0.2.1             |
| MAC:  02:ab:de:8c:30:02    |
| IF:   bridge2              |
+----------------------------+
              |
+----------------------------+
| ROUTER TOWARDS DESTINATION |
| IP:   10.0.2.21            |
| ARP:  02:02:32:38:b0:05    |
+----------------------------+
              |
+----------------------------+
| DESTINATION HOST           |
| IP:   10.0.21.21           |
+----------------------------+
```

```
[root@me]~# graphpath 10.0.11.11 10.0.1.12
+----------------------------+    +----------------------------+
| SOURCE HOST                |    | DESTINATION HOST           |
| IP:   10.0.11.11           |    | IP:  10.0.1.12             |
|                            |    | ARP: 02:01:32:38:b0:04     |
+----------------------------+    +----------------------------+
                  |                             |
+----------------------------+                  |
| ROUTER TOWARDS SOURCE      |                  |
| IP:   10.0.1.11            |                  |
| ARP:  02:01:32:38:b0:03    |                  |
+----------------------------+                  |
              |                                 |
            --+---+-----------------------------+---
                  |
+----------------------------+
| IF:   bridge1              |
| MAC:  02:ab:de:8c:30:01    |
| IP:   10.0.1.1             |
| net:  10.0.11.0            |
| mask: 255.255.255.0        |
|                            |
|         THIS ROUTER        |
+----------------------------+
```

```
[root@me]~# graphpath 10.0.1.12 10.0.11.11
+----------------------------+    +----------------------------+
| SOURCE HOST                |    | DESTINATION HOST           |
| IP:   10.0.1.12            |    | IP:  10.0.11.11            |
| ARP:  02:01:32:38:b0:04    |    |                            |
+----------------------------+    +----------------------------+
                  |                             |
                  |               +----------------------------+
                  |               | ROUTER TOWARDS DESTINATION |
                  |               | IP:   10.0.1.11            |
                  |               | ARP:  02:01:32:38:b0:03    |
                  |               +----------------------------+
                  |                             |
            --+---+-----------------------------+---
                  |
+----------------------------+
| IF:   bridge1              |
| MAC:  02:ab:de:8c:30:01    |
| IP:   10.0.1.1             |
| net:  10.0.1.0             |
| mask: 255.255.255.0        |
|                            |
|         THIS ROUTER        |
+----------------------------+
```
