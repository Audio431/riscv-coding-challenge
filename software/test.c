int sum(const int *a, int n) {
  int total = 0;
  for (int i = 0; i < n; i++)
    total += a[i];
  return total;
}

void scale(int *a, int n, int k) {
  for (int i = 0; i < n; i++)
    a[i] = a[i] * k;
}

int main(void) {
  int a[4] = {1, 2, 3, 4};
  scale(a, 4, 3);
  return sum(a, 4);
}