"""
Targets Manager - Load and save editable targets from JSON.

Provides atomic file writes with backup for data safety.
"""

import json
import logging
import os
import shutil
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional, Union

# Configure logging
logger = logging.getLogger(__name__)

# Path to targets file
TARGETS_FILE = Path(__file__).parent / "targets.json"
BACKUP_FILE = Path(__file__).parent / "targets.json.bak"

# Default targets (fallback if file doesn't exist)
DEFAULT_TARGETS: Dict[str, Any] = {
    "company": {
        "revenue_target": 10_000_000,
        "gross_margin_target": 0.45,
        "nrr_target": 1.10,
        "customer_count_target": 75,
        "pipeline_target": 3.0,
        "logo_retention_target": 0.50,
    },
    "people": {},
    "last_updated": None,
    "updated_by": None,
}


def load_targets() -> Dict[str, Any]:
    """Load targets from JSON file, or return defaults if not found.

    Returns:
        Dictionary containing company and people targets
    """
    if TARGETS_FILE.exists():
        try:
            with open(TARGETS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                logger.debug("Loaded targets from %s", TARGETS_FILE)
                return data
        except json.JSONDecodeError as e:
            logger.error("Invalid JSON in targets file: %s", e)
            return DEFAULT_TARGETS.copy()
        except IOError as e:
            logger.error("Failed to read targets file: %s", e)
            return DEFAULT_TARGETS.copy()
    logger.info("Targets file not found, using defaults")
    return DEFAULT_TARGETS.copy()


def save_targets(targets: Dict[str, Any], updated_by: str = "Admin") -> bool:
    """Save targets to JSON file atomically with backup.

    Creates a backup of the existing file before saving, then writes to a
    temporary file and atomically moves it to the target location.

    Args:
        targets: Dictionary containing targets to save
        updated_by: Name of user making the update

    Returns:
        True if save was successful, False otherwise
    """
    try:
        # Create backup of existing file
        if TARGETS_FILE.exists():
            try:
                shutil.copy2(TARGETS_FILE, BACKUP_FILE)
                logger.debug("Created backup at %s", BACKUP_FILE)
            except IOError as e:
                logger.warning("Failed to create backup: %s", e)
                # Continue anyway - backup is nice-to-have

        # Update metadata
        targets["last_updated"] = datetime.now().isoformat()
        targets["updated_by"] = updated_by

        # Write to temp file first, then atomic move
        fd, temp_path = tempfile.mkstemp(
            dir=TARGETS_FILE.parent,
            suffix=".json",
            prefix=".targets_"
        )
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(targets, f, indent=2)

            # Atomic move (rename is atomic on POSIX systems)
            shutil.move(temp_path, TARGETS_FILE)
            logger.info("Saved targets (updated by %s)", updated_by)
            return True
        except Exception as e:
            # Clean up temp file on failure
            logger.error("Failed to save targets: %s", e)
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            raise
    except (IOError, OSError) as e:
        logger.error("Failed to save targets: %s", e)
        return False


def get_company_target(key: str) -> float:
    """Get a specific company target.

    Args:
        key: The target key (e.g., 'revenue_target', 'gross_margin_target')

    Returns:
        The target value, or 0 if not found
    """
    targets = load_targets()
    return targets.get("company", {}).get(key, 0)


def get_person_target(name: str) -> Dict[str, Any]:
    """Get target info for a specific person.

    Args:
        name: The person's name

    Returns:
        Dictionary with target info, or empty dict if not found
    """
    targets = load_targets()
    return targets.get("people", {}).get(name, {})


def update_company_target(key: str, value: float) -> bool:
    """Update a single company target.

    Args:
        key: The target key to update
        value: The new target value

    Returns:
        True if update was successful
    """
    targets = load_targets()
    if "company" not in targets:
        targets["company"] = {}
    targets["company"][key] = value
    return save_targets(targets)


def update_person_target(name: str, target: float) -> bool:
    """Update a single person's target.

    Args:
        name: The person's name
        target: The new target value

    Returns:
        True if update was successful
    """
    targets = load_targets()
    if "people" not in targets:
        targets["people"] = {}
    if name not in targets["people"]:
        targets["people"][name] = {}
    targets["people"][name]["target"] = target
    return save_targets(targets)


def get_all_targets() -> Dict[str, Any]:
    """Get all targets.

    Returns:
        Complete targets dictionary
    """
    return load_targets()


def restore_from_backup() -> bool:
    """Restore targets from backup file.

    Returns:
        True if restore was successful, False otherwise
    """
    if not BACKUP_FILE.exists():
        logger.warning("No backup file found at %s", BACKUP_FILE)
        return False

    try:
        shutil.copy2(BACKUP_FILE, TARGETS_FILE)
        logger.info("Restored targets from backup")
        return True
    except IOError as e:
        logger.error("Failed to restore from backup: %s", e)
        return False
