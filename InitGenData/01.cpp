#include<algorithm>
#include<fstream>
#include<iostream>
#include<random>
#include<vector>
using namespace std;

struct Node{
	bool operator == (const Node &e){
		 return (this-> == e.);
	}
};

int TestIfSatisfyPre(Node* aNode) {

	if() return 1;
	return -1;
}

int TestIfSatisfyPost(Node* aNode) {

	if() return 1;
	return -1;
}

Node* DoWhile(Node *aNode, vector<Node*>& aSet) {

	Node *_p;
	while(){
		

		_p = new Node;

		vector<Node*>::iterator it = find(aSet.begin(), aSet.end(), _p);
		if(it == aSet.end()) {
			aSet.push_back(_p);
		}
	}
	return _p;
}

void GetPositive(Node *aNode, vector<Node*>& aPositive) {
	int begin = aPositive.size();
	aPositive.push_back(aNode);

	Node *p = DoWhile(aNode, aPositive);
	if(TestIfSatisfyPost(p) == -1) {
		aPositive.erase(aPositive.begin() + begin, aPositive.end());
	}
}

void GetNegative(Node* aNode, vector<Node*>& aNegative) {
	int begin = aNegative.size();
	aNegative.push_back(aNode);

	Node *p = DoWhile(aNode, aNegative);
	if(TestIfSatisfyPost(p) == 1) {
		aNegative.erase(aNegative.begin() + begin, aNegative.end());
	}
}

int main(int argc, char** argv){
    /* store positive and negative examples */
    vector<Node*> positiveSet;
    vector<Node*> negativeSet;

    string outputFileName = "out.ds";

    /* init output file name */
    if(argc < 2);
    else if(argc == 2){
        outputFileName = string(argv[1]);
    }
    else{
        cerr << "More parameters" << endl;
        exit(0);
    }

    ofstream ofs(outputFileName, ofstream::out | ofstream::binary);
    if(ofs){
        /* init random, in (-100, 100) */
        //TODO: how to set the random distribution

        srand((int)time(0));
        while(positiveSet.size() <= 10 || negativeSet.size() <= 10) {
            Node *p = new Node;

            vector<Node*>::iterator it = find(positiveSet.begin(), positiveSet.end(), p);
            if(it != positiveSet.end()) continue;
            it = find(negativeSet.begin(), negativeSet.end(), p);
            if(it != negativeSet.end()) continue;
            int positive = TestIfSatisfyPre(p);
            if(positive == 1) GetPositive(p, positiveSet);
            else GetNegative(p, negativeSet);
        }
        
        /* output example to file */
        for(size_t i = 0;i < positiveSet.size();i++){
            ofs << "1 : ";
			ofs << positiveSet[i]-> << endl;
		}
		for(size_t i = 0;i < negativeSet.size();i++){
			ofs << "-1 : ";
			ofs << negativeSet[i]-> << endl;
        }
        ofs.close();
    }
    else
        cerr << "Cannot open output file: " << outputFileName << endl;
    return 0;
}
