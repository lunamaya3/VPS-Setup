#!/usr/bin/env python3
"""
Credential Generator Utility
CSPRNG-based secure password generation with configurable complexity

Usage:
    python3 credential-gen.py [--length LENGTH] [--format FORMAT]

Options:
    --length LENGTH    Password length (default: 16, minimum: 12)
    --format FORMAT    Output format: plain, secure, json (default: secure)

Formats:
    plain:   Direct password output (use with caution)
    secure:  Masked output with reveal option
    json:    JSON with password and metadata
"""

import secrets
import string
import sys
import json
import argparse
from typing import Dict, Any


class CredentialGenerator:
    """Secure credential generation using CSPRNG"""

    # Character sets for password generation
    LOWERCASE = string.ascii_lowercase
    UPPERCASE = string.ascii_uppercase
    DIGITS = string.digits
    SYMBOLS = "!@#$%^&*()-_=+[]{}|;:,.<>?"

    MIN_LENGTH = 12
    DEFAULT_LENGTH = 16

    def __init__(self, length: int = DEFAULT_LENGTH):
        """
        Initialize credential generator

        Args:
            length: Desired password length (minimum 12)
        """
        if length < self.MIN_LENGTH:
            raise ValueError(
                f"Password length must be at least {self.MIN_LENGTH} characters"
            )
        self.length = length

    def generate_password(
        self,
        use_uppercase: bool = True,
        use_lowercase: bool = True,
        use_digits: bool = True,
        use_symbols: bool = True,
    ) -> str:
        """
        Generate a secure random password

        Args:
            use_uppercase: Include uppercase letters
            use_lowercase: Include lowercase letters
            use_digits: Include numbers
            use_symbols: Include special characters

        Returns:
            Secure random password string

        Raises:
            ValueError: If no character sets are enabled
        """
        # Build character set
        chars = ""
        required_chars = []

        if use_lowercase:
            chars += self.LOWERCASE
            required_chars.append(secrets.choice(self.LOWERCASE))

        if use_uppercase:
            chars += self.UPPERCASE
            required_chars.append(secrets.choice(self.UPPERCASE))

        if use_digits:
            chars += self.DIGITS
            required_chars.append(secrets.choice(self.DIGITS))

        if use_symbols:
            chars += self.SYMBOLS
            required_chars.append(secrets.choice(self.SYMBOLS))

        if not chars:
            raise ValueError("At least one character set must be enabled")

        # Generate remaining characters
        remaining_length = self.length - len(required_chars)
        password_chars = required_chars + [
            secrets.choice(chars) for _ in range(remaining_length)
        ]

        # Shuffle to avoid predictable patterns
        # Use secrets.SystemRandom for cryptographic shuffling
        random_gen = secrets.SystemRandom()
        random_gen.shuffle(password_chars)

        return "".join(password_chars)

    def generate_with_metadata(self) -> Dict[str, Any]:
        """
        Generate password with metadata

        Returns:
            Dict with password and generation metadata
        """
        password = self.generate_password()

        return {
            "password": password,
            "length": len(password),
            "entropy_bits": self.calculate_entropy(password),
            "has_uppercase": any(c in self.UPPERCASE for c in password),
            "has_lowercase": any(c in self.LOWERCASE for c in password),
            "has_digits": any(c in self.DIGITS for c in password),
            "has_symbols": any(c in self.SYMBOLS for c in password),
            "strength": self.assess_strength(password),
        }

    @staticmethod
    def calculate_entropy(password: str) -> float:
        """
        Calculate password entropy in bits

        Args:
            password: Password string

        Returns:
            Entropy value in bits
        """
        import math

        # Determine character set size
        charset_size = 0
        if any(c in string.ascii_lowercase for c in password):
            charset_size += 26
        if any(c in string.ascii_uppercase for c in password):
            charset_size += 26
        if any(c in string.digits for c in password):
            charset_size += 10
        if any(c in "!@#$%^&*()-_=+[]{}|;:,.<>?" for c in password):
            charset_size += 22

        if charset_size == 0:
            return 0.0

        # Entropy = log2(charset_size^length)
        return len(password) * math.log2(charset_size)

    @staticmethod
    def assess_strength(password: str) -> str:
        """
        Assess password strength

        Args:
            password: Password string

        Returns:
            Strength rating: "weak", "moderate", "strong", "very_strong"
        """
        entropy = CredentialGenerator.calculate_entropy(password)

        if entropy < 50:
            return "weak"
        elif entropy < 75:
            return "moderate"
        elif entropy < 100:
            return "strong"
        else:
            return "very_strong"

    @staticmethod
    def format_secure_display(password: str) -> str:
        """
        Format password for secure display (partially masked)

        Args:
            password: Password string

        Returns:
            Formatted display string with instructions
        """
        # Show first 3 and last 3 characters, mask the rest
        if len(password) <= 6:
            masked = "*" * len(password)
        else:
            visible_start = password[:3]
            visible_end = password[-3:]
            masked_middle = "*" * (len(password) - 6)
            masked = f"{visible_start}{masked_middle}{visible_end}"

        return f"""
╔═══════════════════════════════════════════════════════════╗
║                   SECURE CREDENTIAL                       ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  Password (masked): {masked:38s}  ║
║  Length: {len(password):2d} characters                                  ║
║  Strength: {CredentialGenerator.assess_strength(password):45s}  ║
║                                                           ║
║  ⚠️  SECURITY WARNING:                                    ║
║  Copy this password immediately and store securely.      ║
║  It will not be shown again.                             ║
║                                                           ║
║  Full password: {password:42s}  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"""


def main():
    """CLI entry point"""
    parser = argparse.ArgumentParser(
        description="Generate secure passwords using CSPRNG",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    parser.add_argument(
        "--length",
        type=int,
        default=CredentialGenerator.DEFAULT_LENGTH,
        help=f"Password length (default: {CredentialGenerator.DEFAULT_LENGTH}, minimum: {CredentialGenerator.MIN_LENGTH})",
    )

    parser.add_argument(
        "--format",
        choices=["plain", "secure", "json"],
        default="secure",
        help="Output format (default: secure)",
    )

    parser.add_argument(
        "--no-uppercase", action="store_true", help="Exclude uppercase letters"
    )

    parser.add_argument(
        "--no-lowercase", action="store_true", help="Exclude lowercase letters"
    )

    parser.add_argument("--no-digits", action="store_true", help="Exclude digits")

    parser.add_argument("--no-symbols", action="store_true", help="Exclude symbols")

    args = parser.parse_args()

    try:
        generator = CredentialGenerator(length=args.length)

        if args.format == "json":
            result = generator.generate_with_metadata()
            print(json.dumps(result, indent=2))
        elif args.format == "secure":
            password = generator.generate_password(
                use_uppercase=not args.no_uppercase,
                use_lowercase=not args.no_lowercase,
                use_digits=not args.no_digits,
                use_symbols=not args.no_symbols,
            )
            print(generator.format_secure_display(password))
        else:  # plain
            password = generator.generate_password(
                use_uppercase=not args.no_uppercase,
                use_lowercase=not args.no_lowercase,
                use_digits=not args.no_digits,
                use_symbols=not args.no_symbols,
            )
            print(password)

        sys.exit(0)

    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
