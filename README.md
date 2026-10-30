# apple-container

This project makes use of `just` as a wrapper around `apple-container` and `kiac`.

[apple container](https://github.com/apple/container)
[kiac](https://github.com/saiyam1814/kiac)


## Troubleshooting

```
Error: cilium install: exit status 1
ℹ️  Using Cilium version 1.20.1
🔮 Auto-detected cluster name: kiac-devk8s
⏭️ Skipping auto kube-proxy detection

Error: Unable to install Cilium: cluster reachability check failed: kubernetes cluster unreachable: Get "https://192.168.64.5:6443/version": dial tcp 192.168.64.5:6443: connect: no route to host
error: recipe up failed with exit code 1
```

- macOS Local Network permission. macOS 15 and later block apps from reaching local subnets until you allow them, and the error looks exactly like this. Go to System Settings → Privacy & Security → Local Network and turn it on for your terminal app (Ghostty, iTerm, Terminal, VS Code, etc.). Then fully quit and reopen the terminal.
- A VPN or Zero Trust client (Tailscale, Cloudflare WARP, corporate VPN) that captures 192.168.64.0/24. Apple’s container network uses 192.168.64.0/24 by default, and VPN routes are known to interfere with it. Check with netstat -rn -finet | grep 192.168.64. You want to see bridge100, not utun*. Try again with the VPN off.

A quick test that skips Kubernetes entirely:

```bash
container run -d --name nettest docker.io/library/nginx:alpine
container ls                      # note its 192.168.64.x address
curl -m 5 http://<that-ip>        # should return the nginx page
container rm -f nettest
```

If curl fails, the problem is host networking (causes 1–3 above), not kiac. Once curl works, run just up again. kiac already cleaned up the partial cluster, so it will start fresh.
