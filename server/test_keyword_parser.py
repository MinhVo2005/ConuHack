"""
Test the keyword-based fallback parser
Run: python test_keyword_parser.py
"""
import sys
sys.path.insert(0, '.')

from controllers.voice_command import parse_command_with_keywords, extract_amount, extract_name

def test_parser():
    print("Testing Keyword Parser\n" + "=" * 50)

    test_cases = [
        # Balance checks
        ("What's my balance?", "check_balance", {"account_type": "all"}),
        ("Check my savings balance", "check_balance", {"account_type": "savings"}),
        ("How much money do I have?", "check_balance", {"account_type": "all"}),
        ("Show my checking account", "check_balance", {"account_type": "checking"}),
        ("How much in my credit card?", "check_balance", {"account_type": "credit_card"}),
        ("Check my gold", "check_balance", {"account_type": "treasure_chest"}),

        # Transfers
        ("Transfer 50 dollars from checking to savings", "transfer", {"amount": 50, "from_account": "checking", "to_account": "savings"}),
        ("Move $100 to savings", "transfer", {"amount": 100, "to_account": "savings"}),
        ("Transfer fifty dollars to credit card", "transfer", {"amount": 50, "to_account": "credit_card"}),

        # Send money
        ("Send 20 dollars to John", "send_money", {"amount": 20, "recipient_name": "John"}),
        ("Pay Sarah $50", "send_money", {"amount": 50, "recipient_name": "Sarah"}),
        ("Send Mike 100 bucks", "send_money", {"amount": 100, "recipient_name": "Mike"}),

        # Gold exchange
        ("Exchange 2 gold bars", "exchange_gold", {"bars": 2}),
        ("Convert my gold to cash", "exchange_gold", {"bars": 1}),
        ("Sell 5 gold bars to savings", "exchange_gold", {"bars": 5, "to_account": "savings"}),

        # Transactions
        ("Show my transactions", "get_transactions", {"account_type": "all"}),
        ("Recent activity", "get_transactions", {"account_type": "all"}),
        ("Transaction history for savings", "get_transactions", {"account_type": "savings"}),

        # Help
        ("Help", "help", {}),
        ("What can you do?", "help", {}),

        # Unknown
        ("asdfasdf gibberish", "unknown", {}),
        ("hello there", "unknown", {}),
    ]

    passed = 0
    failed = 0

    for transcript, expected_action, expected_params in test_cases:
        result = parse_command_with_keywords(transcript)
        action = result["action"]

        # Check action matches
        action_ok = action == expected_action

        # Check key parameters (not all need to match exactly)
        params_ok = True
        for key, value in expected_params.items():
            if key in result["parameters"]:
                if result["parameters"][key] != value:
                    params_ok = False
            # Some params are optional so don't fail if missing

        if action_ok and params_ok:
            print(f"[OK] '{transcript}'")
            print(f"     -> {action}: {result['parameters']}")
            passed += 1
        else:
            print(f"[FAIL] '{transcript}'")
            print(f"     Expected: {expected_action}: {expected_params}")
            print(f"     Got:      {action}: {result['parameters']}")
            failed += 1

    print("\n" + "=" * 50)
    print(f"Results: {passed} passed, {failed} failed")

    # Test amount extraction separately
    print("\n\nTesting Amount Extraction\n" + "=" * 50)
    amount_tests = [
        ("$50", 50),
        ("50 dollars", 50),
        ("fifty dollars", 50),
        ("$100.50", 100.50),
        ("twenty five bucks", 25),
        ("one hundred dollars", 100),
    ]

    for text, expected in amount_tests:
        result = extract_amount(text)
        status = "[OK]" if result == expected else "[FAIL]"
        print(f"{status} '{text}' -> {result} (expected {expected})")

    # Test name extraction
    print("\n\nTesting Name Extraction\n" + "=" * 50)
    name_tests = [
        ("send money to John", "John"),
        ("pay Sarah", "Sarah"),
        ("send 50 to Mike", "Mike"),
    ]

    for text, expected in name_tests:
        result = extract_name(text)
        status = "[OK]" if result == expected else "[FAIL]"
        print(f"{status} '{text}' -> {result} (expected {expected})")


if __name__ == "__main__":
    test_parser()
