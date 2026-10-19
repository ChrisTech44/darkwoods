"""Source preparation must fail closed even when Godot exits zero on script errors."""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import run_server


class ServerLauncherTests(unittest.TestCase):
    def launch(self, argv, preparation):
        with patch.object(sys, 'argv', ['run_server.py'] + argv), \
             patch.object(run_server, 'godot_binary', return_value='godot'), \
             patch.object(run_server.subprocess, 'run', return_value=preparation) as importing, \
             patch.object(run_server.subprocess, 'call', return_value=0) as serving, \
             contextlib.redirect_stdout(io.StringIO()), \
             contextlib.redirect_stderr(io.StringIO()):
            result = run_server.main()
        return result, importing, serving

    def test_zero_exit_with_script_error_never_starts_server(self):
        result, importing, serving = self.launch([], subprocess.CompletedProcess([], 0, 'SCRIPT ERROR: Parse Error'))
        self.assertEqual(result, 1)
        importing.assert_called_once()
        serving.assert_not_called()

    def test_failed_import_never_starts_server(self):
        result, _, serving = self.launch([], subprocess.CompletedProcess([], 1, 'Import failed'))
        self.assertEqual(result, 1)
        serving.assert_not_called()

    def test_source_prepared_before_runtime(self):
        result, importing, serving = self.launch(['--min-players', '2'], subprocess.CompletedProcess([], 0, 'Imported'))
        self.assertEqual(result, 0)
        self.assertIn('--import', importing.call_args.args[0])
        self.assertIn('Dummy', importing.call_args.args[0])
        self.assertIn('--dedicated-server', serving.call_args.args[0])
        self.assertEqual(serving.call_args.args[0][-6:-4], ['--min-players', '2'])

    def test_disabled_powers_forwarded_to_authority(self):
        result, _, serving = self.launch(['--no-camper-abilities'], subprocess.CompletedProcess([], 0, 'Imported'))
        self.assertEqual(result, 0)
        self.assertIn('--no-camper-abilities', serving.call_args.args[0])

    def test_exported_pack_skips_source_import(self):
        with tempfile.NamedTemporaryFile(suffix='.pck') as pack:
            result, importing, serving = self.launch(['--pack', pack.name], None)
        self.assertEqual(result, 0)
        importing.assert_not_called()
        self.assertIn('--main-pack', serving.call_args.args[0])


if __name__ == '__main__':
    unittest.main()
