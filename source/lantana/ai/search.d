// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ai.search;

/// A* search
bool search(Graph, Node)(ref Graph graph, ref Node start, ref Node end)
{
	start.ante = &start;
	start.minCost = 0;
	start.estimated = graph.estimate(start, end);
	graph.open(&start);

	Node* ante = &start;

	float runningCost = 0;
	while(true)
	{
		Node* n = graph.minimumEstimated(ante, &end);

		if(n is null)
		{
			return false;
		}
		else if(n is &end)
		{
			graph.close(n);
			return true;
		}

		foreach(ref Node.Successor sc; graph.successors(n))
		{
			assert(sc.cost >= 1);
			float g = n.minCost + sc.cost;

			if(!sc.node.closed() || sc.node.minCost > g)
			{
				sc.node.minCost = g;
				sc.node.ante = n;
				sc.node.estimated = g + graph.estimate(*sc.node, end);
				graph.open(sc.node);
			}
		}
		graph.close(n);
		ante = n;
	}
}