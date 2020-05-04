// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ai.search;

/// A* search
bool search(NodeSet, Node)(ref NodeSet set, ref Node start, ref Node end)
{
	start.open();
	start.ante = &start;
	start.minCost = 0;
	start.estimated = set.estimate(start, end);

	Node* ante = &start;

	float runningCost = 0;
	while(true)
	{
		Node* n = set.minimumEstimated(ante, &end);

		if(n is null)
		{
			return false;
		}
		else if(n is &end)
		{
			n.close();
			return true;
		}

		foreach(ref Node.Successor sc; set.successors(n))
		{
			float g = n.minCost + sc.cost;

			if(!sc.node.closed() || sc.node.minCost > g)
			{
				sc.node.open();
				sc.node.minCost = g;
				sc.node.ante = n;
				sc.node.estimated = g + set.estimate(*sc.node, end)/2;
			}
		}
		n.close();
		ante = n;
	}
}