# Intersection Estimator

Intersection Estimator is a demo of using minhash and hyperloglog to do
estimates of intersections of sets. This was used to try out estimators for
[Prolly](https://github.com/iamwilhelm/prolly). You can also use this to
understand MinHash algorithm, as it's a pretty simple implementation.

The estimation of the set comes from the Jaccard Similarity:
```
J(A, B) = |A ∩ B| / |A ∪ B|
```
That the similarity between two sets is the number of intersections divided
by the number of unions.

We can estimate the union with hyperloglog. In this implementation, I use
redis's implementation.

Jaccard Similarity can be estimated using MinHash. MinHash algorithm is
pretty easy, but everyone does a terrible job of explaining it. I suggest you
read [Chapter 3](http://infolab.stanford.edu/~ullman/mmds/ch3.pdf) in
[Mining of Massive Datasets](http://www.mmds.org/). Having an example to
go through makes it much clearer.

Once MinHash is used to estimate the similiarity, it can be multiplied with
the hyperloglog to estimate the size of intersection.

Hyperloglog's error can be bounded, and MinHash's error can be bounded
as well. However to use it in Prolly, I'd have to make many multiplications.
I'm not sure that multiplying errors wouldn't compound it.

I haven't characterized the statistical distribution of the errors, and
I don't know what happens when you multiply these distributions of errors together.
Would they grow unbounded? Or is there is bounded? If you know or know how to
figure it out, lemme know in an issue or PR.
