import json, os, pathlib, subprocess, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
BASE='0042818800dd8188'
ENV={**os.environ,'LC_ALL':'C'}
def policy(mode,*args):
 return subprocess.run(['perl',str(ROOT/'scripts/power-policy.pl'),'target',BASE,mode,*map(str,args)],capture_output=True,text=True,env=ENV)
class PolicyTests(unittest.TestCase):
 def test_restore_exactly(self):
  self.assertEqual(policy('original').stdout.strip(),BASE)
 def test_supported_range_and_bit_preservation(self):
  original=int(BASE,16); mask=0x7fff00007fff
  for p1,p2 in [(30,30),(31,49),(36,48),(56,80),(392,392)]:
   r=policy('custom',p1,p2,1,0);self.assertEqual(r.returncode,0,r.stderr)
   value=int(r.stdout,16)
   self.assertEqual(value&~mask,original&~mask)
   self.assertEqual(value&0x7fff,p1);self.assertEqual((value>>32)&0x7fff,p2)
 def test_invalid_inputs_rejected(self):
  for values in [(29,48,1,0),(393,393,1,0),(40,39,1,0),(40,393,1,0),(40,48,2,0),(40,48,1,3),('40;touch /tmp/no',48,1,0),('40.0',48,1,0),(-40,48,1,0),(40,48,1,0,1)]:
   self.assertNotEqual(policy('custom',*values).returncode,0,values)
 def test_time_windows(self):
  original=int(BASE,16);mask=0x7fff00007fff|(0x7f<<17)
  for tau in [1,2,4,8,16,28]:
   v=int(policy('custom',36,48,0,tau).stdout,16);code=(v>>17)&127
   self.assertEqual((1+(code>>5)/4)*2**(code&31)/1024,tau)
   self.assertEqual(v&~mask,original&~mask)
 def test_capabilities_utf8(self):
  data=subprocess.check_output(['perl',str(ROOT/'scripts/power-policy.pl'),'capabilities',BASE],env=ENV)
  caps=json.loads(data);self.assertEqual(caps['maxPL1'],49)
  self.assertIn('本机',caps['frequencyReason']);self.assertFalse(caps['gpuSupported'])
if __name__=='__main__':unittest.main()
