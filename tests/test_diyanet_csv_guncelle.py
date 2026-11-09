import contextlib
from datetime import date
import importlib.util
import io
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "tools/diyanet_csv_guncelle.py"
SPEC = importlib.util.spec_from_file_location("diyanet_csv_guncelle", SOURCE)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class UpdateCommandTests(unittest.TestCase):
    def test_default_year_is_current_year(self):
        with patch("sys.argv", [str(SOURCE)]), patch.object(MODULE.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(MODULE.main(), 0)
        command = run.call_args.args[0]
        self.assertEqual(command[command.index("-Year") + 1], str(date.today().year))
        self.assertNotIn("-OutputPath", command)

    def test_explicit_year_and_paths_are_forwarded_as_arguments(self):
        output = Path("test folder/vakitler.csv")
        command = MODULE.build_command("İstanbul", "Küçükçekmece", 2028, output)
        self.assertEqual(command[command.index("-Year") + 1], "2028")
        self.assertEqual(command[command.index("-District") + 1], "Küçükçekmece")
        self.assertEqual(command[command.index("-OutputPath") + 1], str(output.resolve()))
        self.assertTrue(Path(command[command.index("-File") + 1]).is_file())

    def test_bad_year_does_not_launch_worker(self):
        with patch("sys.argv", [str(SOURCE), "--year", "1900"]), patch.object(MODULE.subprocess, "run") as run:
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                MODULE.main()
        self.assertEqual(caught.exception.code, 2)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
