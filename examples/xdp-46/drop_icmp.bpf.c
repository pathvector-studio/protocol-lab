// Lab 46: the smallest useful XDP program — drop ICMP, count what you dropped.
//
// XDP runs on the receive path *before* the kernel builds an sk_buff for the
// packet. That is the whole reason this lab exists: a verdict returned here is
// invisible to everything that comes later, including tcpdump.
//
// Every pointer dereference is preceded by a bounds check against
// ctx->data_end. This is not defensive style — the verifier rejects the program
// outright without it, because it cannot otherwise prove the read is in bounds.

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/in.h>
#include <linux/ip.h>
#include <bpf/bpf_helpers.h>

// A one-element array map used as a counter. Userspace reads it with
// `bpftool map dump`, which is how the lab proves the program actually ran
// rather than the packets having gone missing some other way.
struct {
  __uint(type, BPF_MAP_TYPE_ARRAY);
  __uint(max_entries, 1);
  __type(key, __u32);
  __type(value, __u64);
} icmp_drops SEC(".maps");

SEC("xdp")
int drop_icmp(struct xdp_md *ctx) {
  void *data = (void *)(long)ctx->data;
  void *data_end = (void *)(long)ctx->data_end;

  struct ethhdr *eth = data;
  if ((void *)(eth + 1) > data_end)
    return XDP_PASS;
  if (eth->h_proto != __constant_htons(ETH_P_IP))
    return XDP_PASS;

  struct iphdr *ip = (void *)(eth + 1);
  if ((void *)(ip + 1) > data_end)
    return XDP_PASS;
  if (ip->protocol != IPPROTO_ICMP)
    return XDP_PASS;

  __u32 key = 0;
  __u64 *count = bpf_map_lookup_elem(&icmp_drops, &key);
  if (count)
    __sync_fetch_and_add(count, 1);

  return XDP_DROP;
}

char _license[] SEC("license") = "GPL";
