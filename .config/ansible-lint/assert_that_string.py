"""Every `assert` condition is a string.

The schema rule types `when`, `changed_when` and `failed_when`, not `that`. A
bare `: ` in a plain scalar (`^Default: deny`) makes the item a mapping, which
ansible-core refuses only when the assert runs, on a host.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from ansiblelint.rules import AnsibleLintRule

if TYPE_CHECKING:
    from ansiblelint.file_utils import Lintable
    from ansiblelint.utils import Task

_ASSERT = {"assert", "ansible.builtin.assert", "ansible.legacy.assert"}


class AssertThatString(AnsibleLintRule):
    """Assert conditions must be strings."""

    id = "assert-that-string"
    description = "Quote an `assert` condition containing `: `, e.g. with `>-`."
    severity = "VERY_HIGH"
    tags = ["unpredictability"]
    version_changed = "26.9.0"

    def matchtask(self, task: Task, file: Lintable | None = None) -> bool | str:
        if task["action"]["__ansible_module__"] not in _ASSERT:
            return False
        that = task["action"].get("that")
        items = that if isinstance(that, list) else [that]
        bad = [i for i in items if not isinstance(i, (str, bool))]
        return f"not a string: {bad[0]!r}" if bad else False
