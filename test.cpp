#include<algorithm>
#include<ctime>
#include<cstdlib>
#include<fstream>
#include<iostream>
#include<random>
#include<vector>
using namespace std;

struct Node{
    int x;
    int y;
    bool operator == (const Node &e){
        return (this->x == e.x) && (this->y == e.y);
    }
};

int TestIfSatisfyPre(Node* aNode) {
	int x = aNode->x;
    int y = aNode->y;

	if(x<y) return 1;
	return -1;
}

int TestIfSatisfyPost(Node* aNode) {
	int x = aNode->x;
	int y = aNode->y;

	if(((x >= y) && (x <= (y + 16)))) return 1;
	return -1;
}

void GetPositive(Node *aNode, vector<Node*>& aPositive) {
	int begin = aPositive.size();
	aPositive.push_back(aNode);

	int x = aNode->x;
	int y = aNode->y;
    Node *_p;
	while(x < y){
        if(x<0) x=x+7; else x=x+10; if(y<0) y=y-10;else y=y+3; 
        _p = new Node;
        _p->x = x;
        _p->y = y;
		vector<Node*>::iterator it = find(aPositive.begin(), aPositive.end(), _p);
		if(it == aPositive.end()) {
			aPositive.push_back(_p);
		}
	}

	if(TestIfSatisfyPost(_p) == -1) {
		aPositive.erase(aPositive.begin() + begin, aPositive.end());
	}
}

Node* DoWhile(Node *aNode, vector<Node*>& aSet) {
	int x = aNode->x;
	int y = aNode->y;
    Node *_p;
	while(x < y){
        if(x<0) x=x+7; else x=x+10; if(y<0) y=y-10;else y=y+3; 
        _p = new Node;
        _p->x = x;
        _p->y = y;
		vector<Node*>::iterator it = find(aSet.begin(), aSet.end(), _p);
		if(it == aSet.end()) {
			aSet.push_back(_p);
		}
	}
    return _p;
}
void GetNegative(Node *aNode, vector<Node*>& aNegative) {
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

    /* init seed and output file name */
    if(argc < 2) ;
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
            p->x = (rand() % 201) - 100;
            p->y = (rand() % 201) - 100;

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
            ofs << positiveSet[i]->x << ";";
            ofs << positiveSet[i]->y << endl;
        }
        for(size_t i = 0;i < negativeSet.size();i++){
            ofs << "-1 : ";
            ofs << negativeSet[i]->x << ";";
            ofs << negativeSet[i]->y << endl;
        }
        ofs.close();
    }
    else
        cerr << "Cannot open output file: " << outputFileName << endl;
    return 0;
}
