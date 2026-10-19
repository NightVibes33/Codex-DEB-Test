/* Safe Mode Repair: native iOS 15 crash-stack scorer. Never modifies tweaks. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dirent.h>
#include <sys/stat.h>
#include <limits.h>
#include <time.h>
#define MAXTOK 150000
#define MAXTWEAK 600
#define MAXLOG 512
#define MAXIMAGE 2000
typedef struct {const char *s; int n,next,children;char type;} Token;
typedef struct {char name[256];int score,reports;} Tweak;
typedef struct {char path[PATH_MAX];time_t mtime;} Crash;
static Token *tokens;
static int ntok,invalid;
static Tweak tweaks[MAXTWEAK];static int tweaks_n;
static Crash crashes[MAXLOG];static int crashes_n;
static int hits[MAXTWEAK];
static void ws(const char **p){while(**p&&isspace((unsigned char)**p))++*p;}
static int parse(const char **p,int depth){
 ws(p);if(depth>110||ntok>=MAXTOK||!**p){invalid=1;return -1;}
 int i=ntok++;Token *t=&tokens[i];t->s=*p;t->children=0;
 if(**p=='{'||**p=='['){char end=(**p=='{'?'}':']');t->type=**p;++*p;ws(p);
  while(**p&&**p!=end&&!invalid){
   if(**p==','||**p==':'){++*p;continue;}
   if(parse(p,depth+1)<0)break;
   t->children++;ws(p);
  }
  if(**p==end)++*p;else invalid=1;
 }else if(**p=='"'){t->type='"';++*p;t->s=*p;
  while(**p&&**p!='"'){if(**p=='\\'&&(*p)[1])++*p;++*p;}
  t->n=(int)(*p-t->s);if(**p=='"')++*p;else invalid=1;
 }else{t->type='v';while(**p&&**p!=','&&**p!=']'&&**p!='}'&&!isspace((unsigned char)**p))++*p;}
 if(t->type!='"')t->n=(int)(*p-t->s);
 t->next=ntok;return i;
}
static int eq(int idx,const char *s){return idx>=0&&tokens[idx].n==(int)strlen(s)&&!strncmp(tokens[idx].s,s,tokens[idx].n);}
static int prop(int obj,const char *key){
 if(obj<0||tokens[obj].type!='{')return -1;
 for(int i=obj+1;i<tokens[obj].next;){int k=i,v=i+1;if(v>=tokens[obj].next)break;
  if(eq(k,key))return v;
  i=tokens[v].next;}
 return -1;
}
static int number(int idx,int fallback){return idx<0?fallback:atoi(tokens[idx].s);}
static int truth(int idx){return eq(idx,"true")||eq(idx,"1");}
static void valcopy(int idx,char *out,size_t size){
 if(!size)return;out[0]=0;if(idx<0)return;
 size_t len=(size_t)tokens[idx].n;if(len>=size)len=size-1;memcpy(out,tokens[idx].s,len);out[len]=0;
}
static const char *base(const char *s){const char *p=strrchr(s,'/');return p?p+1:s;}
static int tweak_index(const char *lib){
 const char *b=base(lib);if(!*b)return -1;
 for(int i=0;i<tweaks_n;i++){size_t n=strlen(tweaks[i].name);
  if(!strncmp(b,tweaks[i].name,n)&&!strcmp(b+n,".dylib"))return i;
 }
 return -1;
}
static void collect_tweaks(const char *dir){
 DIR *d=opendir(dir);if(!d)return;struct dirent *e;
 while((e=readdir(d))&&tweaks_n<MAXTWEAK){size_t n=strlen(e->d_name);
  if(n<=6||strcmp(e->d_name+n-6,".dylib"))continue;
  char p[PATH_MAX];snprintf(p,sizeof(p),"%s/%s",dir,e->d_name);
  struct stat st;if(stat(p,&st)!=0||!S_ISREG(st.st_mode))continue;
  Tweak *t=&tweaks[tweaks_n++];snprintf(t->name,sizeof(t->name),"%.*s",(int)(n-6),e->d_name);
 }
 closedir(d);
}
static int cmp_crash(const void *a,const void *b){
 const Crash *x=a,*y=b;return(x->mtime<y->mtime)?1:(x->mtime>y->mtime?-1:0);
}
static void collect_dir(const char *dir){
 DIR *d=opendir(dir);if(!d)return;struct dirent *e;
 while((e=readdir(d))&&crashes_n<MAXLOG){const char *n=e->d_name;
  if(strncmp(n,"SpringBoard-",12)&&strncmp(n,"backboardd-",11))continue;
  size_t len=strlen(n);
  if(len<6||(strcmp(n+len-4,".ips")&&strcmp(n+len-6,".crash")))continue;
  Crash *c=&crashes[crashes_n];snprintf(c->path,sizeof(c->path),"%s/%s",dir,n);
  struct stat st;if(stat(c->path,&st)||!S_ISREG(st.st_mode)||st.st_size>16*1024*1024)continue;
  c->mtime=st.st_mtime;crashes_n++;
 }
 closedir(d);
}
static char *read_file(const char *file){
 FILE *f=fopen(file,"rb");if(!f)return NULL;
 if(fseek(f,0,SEEK_END)){fclose(f);return NULL;}
 long size=ftell(f);if(size<0||size>16*1024*1024){fclose(f);return NULL;}
 rewind(f);char *b=malloc((size_t)size+1);if(!b){fclose(f);return NULL;}
 size_t got=fread(b,1,(size_t)size,f);fclose(f);b[got]=0;return b;
}
static void score_frames(int arr,const int *image_map,int image_n,int base_weight){
 if(arr<0||tokens[arr].type!='[')return;
 int order=0;
 for(int i=arr+1;i<tokens[arr].next;i=tokens[i].next,order++){
  int k=number(prop(i,"imageIndex"),-1);
  if(k<0||k>=image_n||image_map[k]<0)continue;
  int weight=order<3?base_weight:order<8?base_weight/2:2;
  int t=image_map[k];if(weight>hits[t])hits[t]=weight;
 }
}
static void inspect_ips(char *json){
 const char *p=json;ws(&p);
 if(*p=='{'){const char *nl=strchr(p,'\n');if(nl){
  const char *q=nl+1;ws(&q);if(*q=='{')p=q;
 }}
 ntok=0;invalid=0;int root=parse(&p,0);if(root<0||invalid)return;
 int used=prop(root,"usedImages");int threads=prop(root,"threads");if(used<0)return;
 int map[MAXIMAGE],n=0;
 for(int i=used+1;i<tokens[used].next&&n<MAXIMAGE;i=tokens[i].next){
  char img[PATH_MAX];valcopy(prop(i,"path"),img,sizeof(img));
  if(!*img)valcopy(prop(i,"name"),img,sizeof(img));
  map[n++]=tweak_index(img);
 }
 int fault=number(prop(root,"faultingThread"),-1);
 if(threads>=0&&tokens[threads].type=='['){int ord=0;
  for(int i=threads+1;i<tokens[threads].next;i=tokens[i].next,ord++)
   if(truth(prop(i,"triggered"))||(fault>=0&&ord==fault))
    score_frames(prop(i,"frames"),map,n,30);
 }
 score_frames(prop(root,"lastExceptionBacktrace"),map,n,28);
}
static void inspect_crash_text(const char *text){
 char *copy=strdup(text);if(!copy)return;int in_crash=0,order=0;
 for(char *line=strtok(copy,"\n");line;line=strtok(NULL,"\n")){
  if(strstr(line," Crashed:")||strstr(line,"Last Exception Backtrace:")){
   in_crash=1;order=0;continue;
  }
  if(in_crash&&(!*line||strstr(line,"Thread ")||strstr(line,"Binary Images:"))){
   in_crash=0;continue;
  }
  if(!in_crash)continue;
  for(int i=0;i<tweaks_n;i++){
   char b[270];snprintf(b,sizeof(b),"%s.dylib",tweaks[i].name);
   if(strstr(line,b)||(strstr(line,tweaks[i].name)&&strstr(line,"0x"))){
    int w=order<3?25:order<8?12:3;if(w>hits[i])hits[i]=w;
   }
  }order++;
 }
 free(copy);
}
int main(int argc,char **argv){
 const char *inj="/var/jb/usr/lib/TweakInject";
 const char *logs="/var/mobile/Library/Logs/CrashReporter";int limit=35;
 for(int i=1;i<argc;i++){
  if(!strcmp(argv[i],"--inject")&&i+1<argc)inj=argv[++i];
  else if(!strcmp(argv[i],"--crashes")&&i+1<argc)logs=argv[++i];
  else if(!strcmp(argv[i],"--limit")&&i+1<argc)limit=atoi(argv[++i]);
 }
 if(limit<1)limit=1;
 if(limit>MAXLOG)limit=MAXLOG;
 tokens=calloc(MAXTOK,sizeof(Token));if(!tokens)return 2;
 collect_tweaks(inj);collect_dir(logs);
 char retired[PATH_MAX];snprintf(retired,sizeof(retired),"%s/Retired",logs);collect_dir(retired);
 qsort(crashes,crashes_n,sizeof(Crash),cmp_crash);
 int examined=0;
 for(int f=0;f<crashes_n&&f<limit;f++){
  char *body=read_file(crashes[f].path);if(!body)continue;
  memset(hits,0,sizeof(hits));size_t n=strlen(body);
  if(n>=4&&!strcmp(crashes[f].path+strlen(crashes[f].path)-4,".ips"))
   inspect_ips(body);
  else inspect_crash_text(body);
  for(int t=0;t<tweaks_n;t++)if(hits[t]>0){
   tweaks[t].score+=hits[t];tweaks[t].reports++;
  }
  examined++;free(body);
 }
 fprintf(stderr,"Crash reports examined: %d (SpringBoard/backboardd). Active tweaks: %d.\n",examined,tweaks_n);
 for(int i=0;i<tweaks_n;i++){
  if(strpbrk(tweaks[i].name,"\t\r\n"))continue;
  printf("%s\t%d\t%d\n",tweaks[i].name,tweaks[i].score,tweaks[i].reports);
 }
 free(tokens);return 0;
}
