"""Unit tests for validation decisions. No live network is required."""

import unittest
from unittest.mock import patch

import email_validator_v2 as validator


class EmailValidatorTests(unittest.TestCase):
    def test_rejects_invalid_syntax_without_dns(self):
        result = validator.validate_email("not-an-email")
        self.assertEqual(result.status, "invalid")
        self.assertIn("syntax", result.layers_failed)

    @patch.object(validator, "_resolve_mx")
    def test_dns_timeout_is_unknown_not_invalid(self, resolve_mx):
        resolve_mx.return_value = ([], "unknown", "DNS timeout")
        result = validator.validate_email("person@example.com")
        self.assertEqual(result.status, "unknown")
        self.assertFalse(result.is_valid)

    @patch.object(validator, "_external_validation", return_value=None)
    @patch.object(validator, "_detect_catch_all", return_value=False)
    @patch.object(validator, "_verify_across_mx")
    @patch.object(validator, "_resolve_mx")
    def test_confirmed_mailbox_is_valid(
        self, resolve_mx, verify_smtp, _catch_all, _external
    ):
        resolve_mx.return_value = (["mx.example.com"], "valid", "")
        verify_smtp.return_value = ("valid", {"state": "valid"})
        result = validator.validate_email("person@example.com")
        self.assertEqual(result.status, "valid")
        self.assertTrue(result.is_valid)
        self.assertGreaterEqual(result.score, 0.9)

    @patch.object(validator, "_external_validation", return_value=None)
    @patch.object(validator, "_detect_catch_all", return_value=True)
    @patch.object(validator, "_verify_across_mx")
    @patch.object(validator, "_resolve_mx")
    def test_catch_all_is_risky_not_confirmed(
        self, resolve_mx, verify_smtp, _catch_all, _external
    ):
        resolve_mx.return_value = (["mx.example.com"], "valid", "")
        verify_smtp.return_value = ("valid", {"state": "valid"})
        result = validator.validate_email("person@example.com")
        self.assertEqual(result.status, "risky")
        self.assertTrue(result.is_valid)

    @patch.object(validator, "_verify_across_mx")
    @patch.object(validator, "_resolve_mx")
    def test_smtp_timeout_is_unknown(self, resolve_mx, verify_smtp):
        resolve_mx.return_value = (["mx.example.com"], "valid", "")
        verify_smtp.return_value = ("unknown", {"state": "unknown"})
        with patch.object(validator, "_detect_catch_all", return_value=None):
            with patch.object(validator, "_external_validation", return_value=None):
                result = validator.validate_email("person@example.com")
        self.assertEqual(result.status, "unknown")
        self.assertFalse(result.is_valid)


if __name__ == "__main__":
    unittest.main()
