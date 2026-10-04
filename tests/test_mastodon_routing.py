"""Run with: uv run --with jinja2 --with pyyaml --no-project python tests/test_mastodon_routing.py."""

import json
from pathlib import Path
import unittest

from jinja2 import Environment, StrictUndefined
import yaml


class MastodonRoutingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        template = Path(__file__).resolve().parents[1] / (
            "src/ansible/playbooks/compose/traefik/apps.yaml.j2"
        )
        env = Environment(undefined=StrictUndefined)
        env.filters["to_json"] = json.dumps
        cls.config = yaml.safe_load(env.from_string(template.read_text()).render(
            headscale_hostname="headscale.levizitting.com",
            uptime_kuma_hostname="uptime.levizitting.com",
        ))

    def test_https_terminates_on_pi_without_proxy_protocol(self):
        router = self.config["tcp"]["routers"]["mastodon-https-passthrough"]
        self.assertEqual(router["rule"], "HostSNI(`social.sgf.dev`)")
        self.assertEqual(router["entryPoints"], ["websecure"])
        self.assertEqual(router["tls"], {"passthrough": True})
        self.assertEqual(router["service"], "mastodon")
        wildcard = self.config["tcp"]["routers"]["sgfdevs-https-passthrough"]
        self.assertGreater(router["priority"], wildcard.get("priority", len(wildcard["rule"])))
        backend = self.config["tcp"]["services"]["mastodon"]["loadBalancer"]
        self.assertEqual(backend["servers"], [
            {"address": "nothotdog.headnet.levizitting.com:443"}
        ])
        self.assertNotIn("proxyProtocol", backend)
        self.assertNotIn("certResolver", router["tls"])

    def test_http_preserves_host_and_acme_path(self):
        router = self.config["http"]["routers"]["mastodon-http-forward"]
        self.assertEqual(router["rule"], "Host(`social.sgf.dev`)")
        self.assertEqual(router["entryPoints"], ["web"])
        self.assertEqual(router["service"], "mastodon")
        wildcard = self.config["http"]["routers"]["sgfdevs-http-forward"]
        self.assertGreater(router["priority"], wildcard["priority"])
        self.assertGreater(router["priority"], 1)  # Static redirect priority.
        self.assertNotIn("middlewares", router)
        self.assertNotIn("tls", router)
        backend = self.config["http"]["services"]["mastodon"]["loadBalancer"]
        self.assertTrue(backend["passHostHeader"])
        self.assertEqual(backend["servers"], [
            {"url": "http://nothotdog.headnet.levizitting.com:80"}
        ])

    def test_cluster_passthrough_remains_unchanged(self):
        for name in ("lz", "sgfdevs"):
            router = self.config["tcp"]["routers"][f"{name}-https-passthrough"]
            self.assertTrue(router["tls"]["passthrough"])
            self.assertEqual(router["service"], f"{name}-ingress")
            backend = self.config["tcp"]["services"][f"{name}-ingress"]["loadBalancer"]
            self.assertEqual(backend["proxyProtocol"], {"version": 2})
            self.assertEqual(len(backend["servers"]), 3)


if __name__ == "__main__":
    unittest.main()
