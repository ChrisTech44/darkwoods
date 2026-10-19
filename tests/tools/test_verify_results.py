"""A successful process exit alone is not a successful integration suite."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
from verify import passing_test_summary
class VerifyResultTests(unittest.TestCase):
    def test_new_suites_cannot_skip_result_validation(self):
        for name in ['four_survivors','ability_feedback','movement_prediction','map_exploration','objective_scenery']:
            with self.subTest(name=name):
                self.assertFalse(passing_test_summary(name,''))
                self.assertFalse(passing_test_summary(name,'{"event":"test_result","failures":1}'))
                self.assertTrue(passing_test_summary(name,'{"event":"test_result","failures":0}'))
    def test_parse_checks_do_not_need_a_test_result(self):
        self.assertTrue(passing_test_summary('parse_tests_integration_four_survivors.gd',''))
        self.assertTrue(passing_test_summary('startup',''))
    def test_duplicate_or_malformed_results_fail(self):
        row='{"event":"test_result","failures":0}\n'
        self.assertFalse(passing_test_summary('four_survivors',row*2))
        self.assertFalse(passing_test_summary('four_survivors','{broken'))
if __name__=='__main__':unittest.main()
