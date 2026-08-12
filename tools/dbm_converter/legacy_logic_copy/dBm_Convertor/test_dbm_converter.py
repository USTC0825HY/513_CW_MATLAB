import math
import unittest

from dbm_converter import from_dbm, from_vpp, from_vrms


class ConversionTests(unittest.TestCase):
    def test_zero_dbm_at_50_ohm(self):
        dbm, vrms, vpp = from_dbm(0, 50)
        self.assertEqual(dbm, 0)
        self.assertAlmostEqual(vrms, math.sqrt(0.001 * 50))
        self.assertAlmostEqual(vpp, 2 * math.sqrt(2) * vrms)

    def test_round_trip_from_vrms(self):
        dbm, vrms, vpp = from_vrms(1, 50)
        self.assertAlmostEqual(dbm, 10 * math.log10(20))
        self.assertAlmostEqual(from_vpp(vpp, 50)[1], vrms)

    def test_rejects_non_positive_voltage_and_impedance(self):
        with self.assertRaises(ValueError):
            from_vrms(0, 50)
        with self.assertRaises(ValueError):
            from_vpp(-1, 50)
        with self.assertRaises(ValueError):
            from_dbm(0, 0)


if __name__ == "__main__":
    unittest.main()
