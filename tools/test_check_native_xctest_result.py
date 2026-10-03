import copy
import unittest

from check_native_xctest_result import validate_results


EXPECTED = "RunnerTests/PracticeAudioArbiterTests/testExactRetiredUserRetryDispatchesCloseThenSettlesOnlyAfterReadback"


class NativeResultGateTest(unittest.TestCase):
    def setUp(self):
        self.summary = {"totalTestCount": 1, "passedTests": 1,
                        "failedTests": 0, "result": "Passed"}
        self.leaf = {"name": EXPECTED.split("/")[-1] + "()",
                     "nodeType": "Test Case", "result": "Passed"}
        self.suite = {"name": "PracticeAudioArbiterTests", "nodeType": "Test Suite",
                      "children": [self.leaf]}
        self.tree = {"testNodes": [{"name": "Runner", "nodeType": "Test Plan",
                                   "children": [{"name": "RunnerTests.xctest",
                                                 "nodeType": "Unit test bundle",
                                                 "children": [self.suite]}]}]}

    def test_exact_named_passed_leaf_is_accepted(self):
        self.assertEqual(validate_results(self.summary, self.tree, [EXPECTED]), [])

    def test_historical_zero_test_success_is_rejected(self):
        summary = {"totalTestCount": 0, "passedTests": 0,
                   "failedTests": 0, "result": "unknown"}
        tree = {"testNodes": [{"name": "Runner", "nodeType": "Test Plan",
                               "result": "unknown"}]}
        self.assertTrue(validate_results(summary, tree, [EXPECTED]))

    def test_same_method_in_wrong_class_is_rejected(self):
        self.suite["name"] = "RunnerTests"
        self.assertTrue(validate_results(self.summary, self.tree, [EXPECTED]))

    def test_plan_labels_cannot_impersonate_a_bundle_or_class(self):
        for target in (self.tree["testNodes"][0]["children"][0], self.suite):
            with self.subTest(target=target["name"]):
                kind = target["nodeType"]
                target["nodeType"] = "Test Plan"
                self.assertTrue(validate_results(self.summary, self.tree, [EXPECTED]))
                target["nodeType"] = kind

    def test_impossible_count_and_missing_intent_are_rejected(self):
        self.assertTrue(validate_results({**self.summary, "passedTests": 2}, self.tree, [EXPECTED]))
        self.assertTrue(validate_results(self.summary, self.tree, []))
        self.assertTrue(validate_results(self.summary, self.tree, [EXPECTED, EXPECTED]))

    def test_skipped_intended_case_cannot_borrow_another_pass(self):
        self.leaf["result"] = "Skipped"
        self.suite["children"].append({"name": "testOther()", "nodeType": "Test Case",
                                      "result": "Passed"})
        self.summary["totalTestCount"] = 2
        self.assertTrue(validate_results(self.summary, self.tree, [EXPECTED]))

    def test_duplicate_leaf_is_rejected(self):
        self.suite["children"].append(copy.deepcopy(self.leaf))
        self.summary.update(totalTestCount=2, passedTests=2)
        self.assertTrue(validate_results(self.summary, self.tree, [EXPECTED]))

    def test_overall_failure_and_malformed_counts_are_rejected(self):
        for change in ({"failedTests": 1}, {"result": "Failed"},
                       {"totalTestCount": True}, {"passedTests": "1"}):
            with self.subTest(change=change):
                self.assertTrue(validate_results({**self.summary, **change}, self.tree, [EXPECTED]))


if __name__ == "__main__":
    unittest.main()
