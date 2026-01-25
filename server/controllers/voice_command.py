import os
import json
import re
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Literal
import google.generativeai as genai

from database import SessionLocal
from services.account_service import AccountService
from services.transaction_service import TransactionService
from services.user_service import UserService

load_dotenv()


# =============================================================================
# KEYWORD-BASED FALLBACK PARSER
# =============================================================================

def parse_command_with_keywords(transcript: str) -> dict:
    """
    Fallback parser using keyword matching when Gemini is unavailable.
    """
    original_text = transcript.strip()
    text = transcript.lower().strip()

    # --- CHECK BALANCE ---
    balance_patterns = [
        r'\b(balance|how much|what\'?s? my|check my|show my)\b.*\b(account|money|have|got)\b',
        r'\b(balance)\b',
        r'\bhow much (do i|money|in)\b',
        r'\bcheck(ing)?\s+(balance|account)\b',
        r'\bcheck\s+(my\s+)?(gold|treasure|saving|checking|credit)\b',
        r'\bhow much.*\b(credit|card|gold|saving|checking)\b',
    ]

    if any(re.search(p, text) for p in balance_patterns):
        # Determine which account
        account_type = "all"
        if "saving" in text:
            account_type = "savings"
        elif "checking" in text or "main" in text:
            account_type = "checking"
        elif "credit" in text or "card" in text:
            account_type = "credit_card"
        elif "gold" in text or "treasure" in text:
            account_type = "treasure_chest"

        return {
            "action": "check_balance",
            "parameters": {"account_type": account_type},
            "confidence": 0.85
        }

    # --- TRANSFER ---
    transfer_patterns = [
        r'\b(transfer|move)\b',
    ]

    if any(re.search(p, text) for p in transfer_patterns):
        # Extract amount
        amount = extract_amount(text)

        # Extract accounts
        from_account = "checking"
        to_account = "savings"

        if "from saving" in text:
            from_account = "savings"
        if "from checking" in text or "from main" in text:
            from_account = "checking"

        if "to saving" in text:
            to_account = "savings"
        if "to checking" in text or "to main" in text:
            to_account = "checking"
        if "to credit" in text or "pay off" in text or "pay credit" in text:
            to_account = "credit_card"

        if amount > 0:
            return {
                "action": "transfer",
                "parameters": {
                    "from_account": from_account,
                    "to_account": to_account,
                    "amount": amount
                },
                "confidence": 0.80
            }

    # --- SEND MONEY ---
    send_patterns = [
        r'\b(send|pay|give)\b.*\b(to|money|\d+|dollar|buck)\b',
        r'\b(send|pay)\s+\w+\s*\$?\d+',  # send John $50
        r'\b(send|pay)\s+\$?\d+',  # send $50
    ]

    if any(re.search(p, text) for p in send_patterns):
        amount = extract_amount(text)
        recipient = extract_name(original_text)  # Use original case for name extraction

        if amount > 0 and recipient:
            return {
                "action": "send_money",
                "parameters": {
                    "recipient_name": recipient,
                    "amount": amount,
                    "from_account": "checking"
                },
                "confidence": 0.75
            }

    # --- EXCHANGE GOLD ---
    gold_patterns = [
        r'\b(exchange|convert|sell)\b.*\bgold\b',
        r'\bgold\b.*\b(exchange|convert|cash)\b',
    ]

    if any(re.search(p, text) for p in gold_patterns):
        # Extract number of bars
        bars = extract_number(text)
        if bars == 0:
            bars = 1  # Default to 1 bar

        to_account = "checking"
        if "saving" in text:
            to_account = "savings"

        return {
            "action": "exchange_gold",
            "parameters": {
                "bars": bars,
                "to_account": to_account
            },
            "confidence": 0.80
        }

    # --- TRANSACTIONS ---
    transaction_patterns = [
        r'\b(transactions?|history|activity)\b',
        r'\brecent\b',
        r'\bshow\s+(my\s+)?(transactions?|history|activity)\b',
    ]

    if any(re.search(p, text) for p in transaction_patterns):
        account_type = "all"
        if "saving" in text:
            account_type = "savings"
        elif "checking" in text:
            account_type = "checking"

        return {
            "action": "get_transactions",
            "parameters": {"account_type": account_type, "limit": 5},
            "confidence": 0.85
        }

    # --- HELP ---
    help_patterns = [
        r'\b(help|what can you|how do i|commands)\b',
    ]

    if any(re.search(p, text) for p in help_patterns):
        return {
            "action": "help",
            "parameters": {},
            "confidence": 0.90
        }

    # --- UNKNOWN ---
    return {
        "action": "unknown",
        "parameters": {},
        "confidence": 0.0
    }


def extract_amount(text: str) -> float:
    """Extract dollar amount from text."""
    # Match patterns like: $50, 50 dollars, fifty dollars, 50 bucks

    # Numeric patterns: $50, 50 dollars, 50 bucks
    patterns = [
        r'\$\s*(\d+(?:\.\d{2})?)',  # $50 or $50.00
        r'(\d+(?:\.\d{2})?)\s*(?:dollars?|bucks?)',  # 50 dollars
        r'(\d+(?:\.\d{2})?)\s*(?:to|from)',  # 50 to/from (contextual)
    ]

    for pattern in patterns:
        match = re.search(pattern, text.lower())
        if match:
            return float(match.group(1))

    # Word-to-number mapping for common amounts
    word_numbers = {
        'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
        'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
        'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
        'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
        'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
        'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
        'hundred': 100, 'thousand': 1000,
    }

    # Simple word number extraction (e.g., "fifty dollars", "twenty five")
    words = text.lower().split()
    total = 0
    current = 0

    for word in words:
        word = word.strip('$,.')
        if word in word_numbers:
            val = word_numbers[word]
            if val >= 100:
                current = current * val if current else val
            else:
                current += val
        elif current > 0 and word in ['dollars', 'dollar', 'bucks', 'buck']:
            total = current
            current = 0

    if current > 0:
        total = current

    return float(total)


def extract_number(text: str) -> int:
    """Extract a simple number from text."""
    # First try digits
    match = re.search(r'(\d+)', text)
    if match:
        return int(match.group(1))

    # Try word numbers
    word_numbers = {
        'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
        'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    }

    for word, num in word_numbers.items():
        if word in text.lower():
            return num

    return 0


def extract_name(text: str) -> Optional[str]:
    """Extract a person's name from text."""
    # Pattern: "to [Name]" or "send [Name]"
    patterns = [
        r'\bto\s+([A-Z][a-z]+)',  # to John
        r'\bsend\s+(?:\w+\s+)*?([A-Z][a-z]+)',  # send money to John
        r'\bpay\s+([A-Z][a-z]+)',  # pay John
    ]

    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            name = match.group(1)
            # Filter out common non-name words
            if name.lower() not in ['my', 'the', 'a', 'an', 'to', 'from', 'checking', 'savings', 'account']:
                return name

    # Fallback: look for capitalized words that might be names
    # after keywords like "to", "send", "pay"
    text_lower = text.lower()
    for keyword in ['to ', 'send ', 'pay ']:
        if keyword in text_lower:
            idx = text_lower.find(keyword) + len(keyword)
            remaining = text[idx:].strip().split()
            for word in remaining:
                # Skip amounts and common words
                if word[0].isupper() and word.lower() not in ['dollars', 'bucks', 'checking', 'savings']:
                    return word.strip('.,!?')

    return None

# Initialize the Router
router = APIRouter(
    prefix="/api",
    tags=["Voice Command Operations"]
)

# Configure Gemini
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
# Use gemini-2.0-flash (current available model)
model = genai.GenerativeModel("gemini-2.0-flash")

# Request/Response models
class VoiceCommandRequest(BaseModel):
    user_id: str
    transcript: str

class VoiceCommandResponse(BaseModel):
    success: bool
    action: str
    spoken_response: str
    data: Optional[dict] = None
    error: Optional[str] = None

# System prompt for Gemini to parse banking commands
SYSTEM_PROMPT = """You are a banking voice command parser. Your job is to convert natural language banking requests into structured JSON commands.

Available commands:
1. check_balance - Check account balance
   - account_type: "checking", "savings", "credit_card", or "treasure_chest" (gold bars)
   - If user says "all" or doesn't specify, use "all"

2. transfer - Transfer money between user's own accounts
   - from_account: "checking" or "savings"
   - to_account: "checking", "savings", or "credit_card" (to pay off debt)
   - amount: number (in dollars)

3. send_money - Send money to another person
   - recipient_name: string (the person's name to search for)
   - amount: number (in dollars)
   - from_account: "checking" or "savings" (default: "checking")

4. exchange_gold - Convert gold bars to cash
   - bars: number of gold bars to exchange
   - to_account: "checking" or "savings" (default: "checking")

5. get_transactions - Get recent transaction history
   - account_type: "checking", "savings", "credit_card", "treasure_chest", or "all"
   - limit: number (default: 5)

6. help - User needs help or is confused
   - No parameters needed

7. unknown - Cannot understand the request
   - No parameters needed

RULES:
- Always respond with valid JSON only, no other text
- Parse amounts carefully: "fifty dollars" = 50, "one hundred" = 100, "5 bucks" = 5
- Account synonyms: "main account" = "checking", "emergency fund" = "savings", "gold" = "treasure_chest"
- If the user mentions a person's name for sending money, extract it as recipient_name
- Be flexible with phrasing but strict with JSON format

Response format:
{
  "action": "command_name",
  "parameters": { ... },
  "confidence": 0.0-1.0
}

Examples:
User: "What's my balance?"
{"action": "check_balance", "parameters": {"account_type": "all"}, "confidence": 0.95}

User: "How much do I have in savings?"
{"action": "check_balance", "parameters": {"account_type": "savings"}, "confidence": 0.98}

User: "Transfer 50 dollars from checking to savings"
{"action": "transfer", "parameters": {"from_account": "checking", "to_account": "savings", "amount": 50}, "confidence": 0.95}

User: "Send 20 bucks to John"
{"action": "send_money", "parameters": {"recipient_name": "John", "amount": 20, "from_account": "checking"}, "confidence": 0.90}

User: "Exchange 2 gold bars"
{"action": "exchange_gold", "parameters": {"bars": 2, "to_account": "checking"}, "confidence": 0.95}

User: "Show my recent transactions"
{"action": "get_transactions", "parameters": {"account_type": "all", "limit": 5}, "confidence": 0.92}

User: "Gibberish asdfasdf"
{"action": "unknown", "parameters": {}, "confidence": 0.1}
"""


def get_db_session():
    return SessionLocal()


async def parse_command_with_gemini(transcript: str) -> dict:
    """
    Use Gemini to parse the transcript into a structured command.
    Falls back to keyword matching if Gemini fails.
    """
    try:
        prompt = f"{SYSTEM_PROMPT}\n\nUser: \"{transcript}\"\n\nRespond with JSON only:"

        response = model.generate_content(prompt)
        response_text = response.text.strip()

        # Clean up response - remove markdown code blocks if present
        if response_text.startswith("```"):
            lines = response_text.split("\n")
            response_text = "\n".join(lines[1:-1])

        result = json.loads(response_text)
        result["parser"] = "gemini"  # Track which parser was used
        return result

    except json.JSONDecodeError as e:
        print(f"Gemini JSON parse error: {e}, falling back to keywords")
        result = parse_command_with_keywords(transcript)
        result["parser"] = "keywords"
        result["gemini_error"] = f"JSON parse error: {str(e)}"
        return result

    except Exception as e:
        # Gemini failed (quota, network, etc.) - use keyword fallback
        print(f"Gemini API error: {e}, falling back to keywords")
        result = parse_command_with_keywords(transcript)
        result["parser"] = "keywords"
        result["gemini_error"] = str(e)
        return result


def execute_check_balance(user_id: str, params: dict) -> dict:
    """Execute balance check command."""
    db = get_db_session()
    try:
        account_service = AccountService(db)
        account_type = params.get("account_type", "all")

        if account_type == "all":
            summary = account_service.get_account_summary(user_id)
            accounts = summary["accounts"]

            # Build spoken response
            parts = []
            for acc in accounts:
                if acc["type"] == "treasure_chest":
                    parts.append(f"You have {int(acc['balance'])} gold bars in your treasure chest")
                elif acc["type"] == "credit_card":
                    if acc["balance"] > 0:
                        parts.append(f"You owe ${acc['balance']:.2f} on your credit card")
                    else:
                        parts.append("Your credit card has no balance")
                else:
                    parts.append(f"Your {acc['type']} account has ${acc['balance']:.2f}")

            spoken = ". ".join(parts) + "."
            return {
                "success": True,
                "spoken_response": spoken,
                "data": summary
            }
        else:
            balance = account_service.get_balance_by_type(user_id, account_type)

            if account_type == "treasure_chest":
                spoken = f"You have {int(balance)} gold bars in your treasure chest."
            elif account_type == "credit_card":
                if balance > 0:
                    spoken = f"You owe ${balance:.2f} on your credit card."
                else:
                    spoken = "Your credit card has no balance."
            else:
                spoken = f"Your {account_type} account balance is ${balance:.2f}."

            return {
                "success": True,
                "spoken_response": spoken,
                "data": {"account_type": account_type, "balance": balance}
            }
    except HTTPException as e:
        return {"success": False, "spoken_response": e.detail, "error": e.detail}
    except Exception as e:
        return {"success": False, "spoken_response": f"Error checking balance: {str(e)}", "error": str(e)}
    finally:
        db.close()


def execute_transfer(user_id: str, params: dict) -> dict:
    """Execute transfer between own accounts."""
    db = get_db_session()
    try:
        account_service = AccountService(db)
        transaction_service = TransactionService(db)

        from_type = params.get("from_account", "checking")
        to_type = params.get("to_account", "savings")
        amount = params.get("amount", 0)

        if amount <= 0:
            return {
                "success": False,
                "spoken_response": "Please specify a valid amount to transfer.",
                "error": "Invalid amount"
            }

        from_account = account_service.get_account_by_type(user_id, from_type)
        to_account = account_service.get_account_by_type(user_id, to_type)

        transaction = transaction_service.transfer(
            from_account.id,
            to_account.id,
            amount,
            f"Voice command transfer"
        )

        # Get updated balances
        new_from_balance = account_service.get_balance(from_account.id)
        new_to_balance = account_service.get_balance(to_account.id)

        if to_type == "credit_card":
            spoken = f"Done! I've transferred ${amount:.2f} from {from_type} to pay off your credit card. Your {from_type} balance is now ${new_from_balance:.2f}, and your credit card balance is ${new_to_balance:.2f}."
        else:
            spoken = f"Done! I've transferred ${amount:.2f} from {from_type} to {to_type}. Your {from_type} balance is now ${new_from_balance:.2f}, and your {to_type} balance is ${new_to_balance:.2f}."

        return {
            "success": True,
            "spoken_response": spoken,
            "data": {
                "transaction_id": transaction.id,
                "amount": amount,
                "from_balance": new_from_balance,
                "to_balance": new_to_balance
            }
        }
    except HTTPException as e:
        return {"success": False, "spoken_response": e.detail, "error": e.detail}
    except Exception as e:
        return {"success": False, "spoken_response": f"Transfer failed: {str(e)}", "error": str(e)}
    finally:
        db.close()


def execute_send_money(user_id: str, params: dict) -> dict:
    """Execute sending money to another user."""
    db = get_db_session()
    try:
        user_service = UserService(db)
        transaction_service = TransactionService(db)
        account_service = AccountService(db)

        recipient_name = params.get("recipient_name", "")
        amount = params.get("amount", 0)
        from_account_type = params.get("from_account", "checking")

        if not recipient_name:
            return {
                "success": False,
                "spoken_response": "Please specify who you want to send money to.",
                "error": "No recipient specified"
            }

        if amount <= 0:
            return {
                "success": False,
                "spoken_response": "Please specify a valid amount to send.",
                "error": "Invalid amount"
            }

        # Search for recipient
        recipients = user_service.find_users(recipient_name)

        if not recipients:
            return {
                "success": False,
                "spoken_response": f"I couldn't find anyone named {recipient_name}. Please check the name and try again.",
                "error": "Recipient not found"
            }

        if len(recipients) > 1:
            names = ", ".join([r.name for r in recipients[:3]])
            return {
                "success": False,
                "spoken_response": f"I found multiple people matching that name: {names}. Please be more specific.",
                "error": "Multiple recipients found",
                "data": {"matches": [r.to_dict() for r in recipients[:5]]}
            }

        recipient = recipients[0]

        # Can't send to yourself
        if recipient.id == user_id:
            return {
                "success": False,
                "spoken_response": "You can't send money to yourself. Use transfer instead.",
                "error": "Cannot send to self"
            }

        transaction = transaction_service.send_money(
            user_id,
            recipient.id,
            amount,
            from_account_type,
            "checking",
            f"Voice command: Send to {recipient.name}"
        )

        new_balance = account_service.get_balance_by_type(user_id, from_account_type)

        spoken = f"Done! I've sent ${amount:.2f} to {recipient.name}. Your {from_account_type} balance is now ${new_balance:.2f}."

        return {
            "success": True,
            "spoken_response": spoken,
            "data": {
                "transaction_id": transaction.id,
                "recipient_name": recipient.name,
                "amount": amount,
                "new_balance": new_balance
            }
        }
    except HTTPException as e:
        return {"success": False, "spoken_response": e.detail, "error": e.detail}
    except Exception as e:
        return {"success": False, "spoken_response": f"Send failed: {str(e)}", "error": str(e)}
    finally:
        db.close()


def execute_exchange_gold(user_id: str, params: dict) -> dict:
    """Execute gold bar exchange."""
    db = get_db_session()
    try:
        transaction_service = TransactionService(db)
        account_service = AccountService(db)

        bars = params.get("bars", 1)
        to_account_type = params.get("to_account", "checking")

        if bars <= 0:
            return {
                "success": False,
                "spoken_response": "Please specify how many gold bars you want to exchange.",
                "error": "Invalid number of bars"
            }

        gold_value = transaction_service.get_gold_bar_value()
        total_cash = bars * gold_value

        transaction = transaction_service.exchange_gold(user_id, bars, to_account_type)

        new_balance = account_service.get_balance_by_type(user_id, to_account_type)
        remaining_gold = account_service.get_balance_by_type(user_id, "treasure_chest")

        bar_word = "bar" if bars == 1 else "bars"
        spoken = f"Done! I've exchanged {bars} gold {bar_word} for ${total_cash:,.2f}. Your {to_account_type} balance is now ${new_balance:,.2f}. You have {int(remaining_gold)} gold bars remaining."

        return {
            "success": True,
            "spoken_response": spoken,
            "data": {
                "transaction_id": transaction.id,
                "bars_exchanged": bars,
                "cash_received": total_cash,
                "new_balance": new_balance,
                "remaining_gold": int(remaining_gold)
            }
        }
    except HTTPException as e:
        return {"success": False, "spoken_response": e.detail, "error": e.detail}
    except Exception as e:
        return {"success": False, "spoken_response": f"Exchange failed: {str(e)}", "error": str(e)}
    finally:
        db.close()


def execute_get_transactions(user_id: str, params: dict) -> dict:
    """Execute transaction history retrieval."""
    db = get_db_session()
    try:
        transaction_service = TransactionService(db)
        account_service = AccountService(db)

        account_type = params.get("account_type", "all")
        limit = params.get("limit", 5)

        if account_type == "all":
            transactions = transaction_service.get_transaction_history(user_id, limit)
        else:
            account = account_service.get_account_by_type(user_id, account_type)
            transactions = transaction_service.get_account_transactions(account.id, limit)

        if not transactions:
            return {
                "success": True,
                "spoken_response": "You don't have any recent transactions.",
                "data": {"transactions": []}
            }

        # Build spoken summary
        parts = [f"Here are your last {len(transactions)} transactions:"]
        for i, t in enumerate(transactions[:5], 1):
            if t.type == "transfer":
                parts.append(f"{i}. Transfer of ${t.amount:.2f}")
            elif t.type == "deposit":
                parts.append(f"{i}. Deposit of ${t.amount:.2f}")
            elif t.type == "withdrawal":
                parts.append(f"{i}. Withdrawal of ${t.amount:.2f}")
            elif t.type == "gold_exchange":
                parts.append(f"{i}. Gold exchange of {int(t.amount)} bars")

        spoken = " ".join(parts)

        return {
            "success": True,
            "spoken_response": spoken,
            "data": {"transactions": [t.to_dict() for t in transactions]}
        }
    except HTTPException as e:
        return {"success": False, "spoken_response": e.detail, "error": e.detail}
    except Exception as e:
        return {"success": False, "spoken_response": f"Error getting transactions: {str(e)}", "error": str(e)}
    finally:
        db.close()


def execute_help(user_id: str, params: dict) -> dict:
    """Provide help information."""
    spoken = """I can help you with the following commands:
    Say 'check my balance' to see your account balances.
    Say 'transfer' followed by an amount and account names to move money between your accounts.
    Say 'send' followed by an amount and a person's name to send them money.
    Say 'exchange gold' to convert your gold bars to cash.
    Say 'show transactions' to see your recent activity.
    Just shake your phone to activate me anytime!"""

    return {
        "success": True,
        "spoken_response": spoken,
        "data": {"commands": ["check_balance", "transfer", "send_money", "exchange_gold", "get_transactions"]}
    }


def execute_unknown(user_id: str, params: dict) -> dict:
    """Handle unknown commands."""
    return {
        "success": False,
        "spoken_response": "I'm sorry, I didn't understand that. You can ask me to check your balance, transfer money, send money to someone, exchange gold bars, or show your transactions. Say 'help' for more options.",
        "error": "Unknown command"
    }


# Command executor mapping
COMMAND_EXECUTORS = {
    "check_balance": execute_check_balance,
    "transfer": execute_transfer,
    "send_money": execute_send_money,
    "exchange_gold": execute_exchange_gold,
    "get_transactions": execute_get_transactions,
    "help": execute_help,
    "unknown": execute_unknown,
}


@router.post("/voice-command", response_model=VoiceCommandResponse)
async def process_voice_command(request: VoiceCommandRequest):
    """
    Process a voice command from transcribed text.

    1. Parse the transcript using Gemini to extract intent
    2. Execute the appropriate banking operation
    3. Return a spoken response
    """
    try:
        # Parse the command with Gemini
        parsed = await parse_command_with_gemini(request.transcript)

        action = parsed.get("action", "unknown")
        parameters = parsed.get("parameters", {})
        confidence = parsed.get("confidence", 0.0)

        # If confidence is too low, treat as unknown
        if confidence < 0.5:
            action = "unknown"

        # Execute the command
        executor = COMMAND_EXECUTORS.get(action, execute_unknown)
        result = executor(request.user_id, parameters)

        return VoiceCommandResponse(
            success=result.get("success", False),
            action=action,
            spoken_response=result.get("spoken_response", "Something went wrong."),
            data=result.get("data"),
            error=result.get("error")
        )
    except Exception as e:
        return VoiceCommandResponse(
            success=False,
            action="error",
            spoken_response=f"An error occurred: {str(e)}",
            error=str(e)
        )
