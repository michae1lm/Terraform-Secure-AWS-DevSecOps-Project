"""Offline structural checks. These are NOT a substitute for terraform validate or AWS tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class RepositoryTests(unittest.TestCase):
    def test_expected_modules(self):
        for name in (
            'account-baseline', 'secure-s3', 'logging', 'network',
            'detection', 'compute', 'github-oidc'
        ):
            with self.subTest(name=name):
                self.assertTrue((ROOT / 'modules' / name / 'main.tf').exists())

    def test_no_default_ec2_or_paid_endpoints(self):
        text = (ROOT / 'envs/dev/variables.tf').read_text()
        for flag in ('enable_compute', 'enable_private_endpoints'):
            self.assertRegex(text, rf'variable "{flag}"\s*\{{[^}}]*default\s*=\s*false')

    def test_remote_state_not_committed(self):
        ignore = (ROOT / '.gitignore').read_text()
        for marker in ('*.tfstate', 'backend.hcl', '*.tfvars', '*.tfplan'):
            self.assertIn(marker, ignore)

    def test_apply_is_manual_dispatch_only(self):
        workflow = (ROOT / '.github/workflows/terraform.yml').read_text()
        self.assertIn("github.event_name == 'workflow_dispatch'", workflow)
        self.assertIn('environment: production', workflow)
        self.assertIn('inputs.confirmation', workflow)

    def test_bootstrap_holds_oidc_not_dev(self):
        self.assertIn('module "github_oidc"', (ROOT / 'bootstrap/main.tf').read_text())
        self.assertNotIn('module "github_oidc"', (ROOT / 'envs/dev/main.tf').read_text())

    def test_imdsv2_and_private_instance(self):
        compute = (ROOT / 'modules/compute/main.tf').read_text()
        self.assertIn('http_tokens                 = "required"', compute)
        self.assertIn('associate_public_ip_address = false', compute)
        self.assertNotIn('key_name', compute)

    def test_documented_security_limitations(self):
        readme = (ROOT / 'README.md').read_text()
        self.assertIn('not yet deployed', readme.lower())
        self.assertIn('PowerUserAccess', readme)

if __name__ == '__main__':
    unittest.main()
