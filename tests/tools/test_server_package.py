"""Exports must advertise current rules and never publish a stale PCK as new."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import package_server


class ServerPackageTests(unittest.TestCase):
    def test_rules_read_from_game(self):
        self.assertEqual(package_server.protocol_rules(), 'lnac-net-21')

    def test_missing_protocol_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);path=root/'scripts/network';path.mkdir(parents=True)
            (path/'network_session.gd').write_text('extends Node\n')
            with self.assertRaises(ValueError): package_server.protocol_rules(root)

    def test_successful_exit_without_new_pack_cannot_repackage_stale_file(self):
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp);(out/'last-night-server.pck').write_bytes(b'old pack')
            (out/'last-night-server.zip').write_bytes(b'old bundle')
            with patch.object(package_server.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'Done')),contextlib.redirect_stdout(io.StringIO()):
                result=package_server.build_bundle('godot',out)
            self.assertEqual(result,1)
            self.assertEqual((out/'last-night-server.zip').read_bytes(),b'old bundle')
            self.assertEqual((out/'last-night-server.pck').read_bytes(),b'old pack')

    def test_current_metadata_and_archive_come_from_same_new_build(self):
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp)
            def export(cmd,**kwargs):
                Path(cmd[-1]).write_bytes(b'fresh verified pack')
                return subprocess.CompletedProcess(cmd,0,'Done')
            def info(cmd,**kwargs):
                if cmd[-1]=='--version': return '4.7.2.stable.test\n'
                if cmd[:2]==['git','status']: return ' M tools/package_server.py\n'
                return 'commit-for-test\n'
            with patch.object(package_server.subprocess,'run',side_effect=export),patch.object(package_server.subprocess,'check_output',side_effect=info),contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(package_server.build_bundle('godot',out),0)
            with zipfile.ZipFile(out/'last-night-server.zip') as bundle:
                meta=json.loads(bundle.read('build.json'))
                self.assertEqual(meta['rules'],package_server.protocol_rules())
                self.assertEqual(meta['engine'],'4.7.2')
                self.assertTrue(meta['worktree_dirty'])
                self.assertEqual(bundle.read('last-night-server.pck'),b'fresh verified pack')
                self.assertEqual(bundle.read('build.json'),(out/'build.json').read_bytes())


if __name__=='__main__': unittest.main()
