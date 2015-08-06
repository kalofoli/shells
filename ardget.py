#! /usr/bin/env python3

import re
import json
import urllib.request
import sys

if __name__=='__main__':
	arg = sys.argv[1]
	
	if len(sys.argv)>2:
		q = int(sys.argv[2])
	else:
		q=1
	docid = ''
	m = re.match('([0-9]+)|.*documentId=([0-9]+)[^0-9].*',arg)
	if m is not None:
		docid = tuple(filter(lambda x:x is not None,m.groups()))
	if not len(docid):
		raise Exception('Could not parse URL.')
		
	docid = docid[0]
	
	r = urllib.request.urlopen('http://www.ardmediathek.de/play/media/{0}?devicetype=pc&features=flash'.format(docid))
	js = json.loads(r.read().decode('latin'))

	url = sorted(tuple(filter(lambda x:x['_plugin']==1,js['_mediaArray']))[0]['_mediaStreamArray'],key=lambda x:x['_quality'],reverse=True)[q]['_stream']
	
	print(url)
