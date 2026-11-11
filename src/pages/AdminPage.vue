<template>
  <q-page class="admin-page"><main class="admin-page__shell">
    <header class="admin-page__header"><div><span class="eyebrow">Panel seguro</span><h1>Contenido y eventos</h1><p>Alta, edición, orden y despublicación. Las soluciones solo son visibles para administradores.</p></div><q-btn flat no-caps label="Volver" to="/" /></header>
    <q-banner v-if="!authorized" rounded class="denied"><q-icon name="lock" /> Esta cuenta no tiene permisos de administrador.</q-banner>
    <template v-else>
      <q-tabs v-model="tab" align="left" outside-arrows mobile-arrows class="tabs">
        <q-tab v-for="item in entities" :key="item.key" :name="item.key" :label="item.label" />
      </q-tabs>
      <section class="panel">
        <div class="panel__bar"><div><span class="eyebrow">Gestor</span><h2>{{ current.label }}</h2></div><q-btn color="primary" unelevated no-caps icon="add" label="Nuevo" @click="createItem" /></div>
        <q-input v-model="filter" outlined dense clearable label="Filtrar resultados" class="filter" />
        <div v-if="loading" class="state"><q-spinner color="primary" size="34px" /></div>
        <q-list v-else bordered separator class="items">
          <q-item v-for="item in filteredItems" :key="item.id">
            <q-item-section><q-item-label>{{ item[current.title] || item.id }}</q-item-label><q-item-label caption>{{ subtitle(item) }}</q-item-label></q-item-section>
            <q-item-section side class="actions"><q-btn flat round icon="edit" @click="editItem(item)" /><q-btn v-if="current.publish" flat round :icon="isPublished(item) ? 'visibility_off' : 'visibility'" @click="togglePublish(item)" /></q-item-section>
          </q-item>
          <q-item v-if="!filteredItems.length"><q-item-section class="empty">No hay registros para mostrar.</q-item-section></q-item>
        </q-list>
      </section>
    </template>
    <q-dialog v-model="dialog"><q-card class="form-card"><q-card-section><span class="eyebrow">Edición segura</span><h2>{{ form.id ? 'Modificar' : 'Alta' }} · {{ current.label }}</h2>
      <template v-for="field in current.fields" :key="field.key">
        <q-select v-if="field.parent || field.key === 'estado' || field.key === 'dificultad'" v-model="form[field.key]" :options="fieldOptions(field)" emit-value map-options :label="field.label" :rules="field.required ? [required] : []" />
        <q-toggle v-else-if="field.type === 'boolean'" v-model="form[field.key]" :label="field.label" />
        <q-input v-else v-model="form[field.key]" :type="field.type || 'text'" :label="field.label" :rules="field.required ? [required] : []" />
      </template>
      <q-banner v-if="formError" class="form-error" rounded>{{ formError }}</q-banner>
    </q-card-section><q-card-actions align="right"><q-btn flat no-caps label="Cancelar" v-close-popup /><q-btn color="primary" no-caps label="Guardar" :loading="saving" @click="saveItem" /></q-card-actions></q-card></q-dialog>
  </main></q-page>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { getSupabaseClient } from '@/lib/supabase'

const db = getSupabaseClient(); const tab = ref('courses'); const authorized = ref(false); const filter = ref(''); const dialog = ref(false); const loading = ref(false); const saving = ref(false); const formError = ref(''); const form = ref({}); const rows = ref([]); const parents = ref({})
const required = value => (value !== null && value !== undefined && String(value).trim() !== '') || 'Obligatorio'
const entities = [
  { key:'courses', table:'cursos', label:'Cursos', title:'titulo', order:'orden', publish:'estado', fields:[['slug','Slug',1],['titulo','Título',1],['descripcion','Descripción',1],['nivel','Nivel',1],['estado','Estado',1],['color','Color',1],['icono','Ícono',1],['orden','Orden',1,'number']] },
  { key:'units', table:'unidades', label:'Unidades', title:'titulo', order:'orden', publish:'disponible', fields:[['curso_id','Curso',1,'select','courses'],['orden','Orden',1,'number'],['titulo','Título',1],['descripcion','Descripción',1],['icono','Ícono',1],['disponible','Publicada',0,'boolean']] },
  { key:'lessons', table:'lecciones', label:'Lecciones', title:'titulo', order:'orden', fields:[['unidad_id','Unidad',1,'select','units'],['orden','Orden',1,'number'],['titulo','Título',1],['explicacion','Explicación',1],['ejemplo_codigo','Ejemplo de código',0]] },
  { key:'questions', table:'preguntas', label:'Preguntas', title:'enunciado', order:'orden', fields:[['leccion_id','Lección',1,'select','lessons'],['orden','Orden',1,'number'],['enunciado','Enunciado',1],['codigo','Código opcional',0]] },
  { key:'options', table:'opciones', label:'Opciones', title:'texto', order:'orden', fields:[['pregunta_id','Pregunta',1,'select','questions'],['orden','Orden',1,'number'],['texto','Texto',1]] },
  { key:'solutions', table:'soluciones', label:'Soluciones', title:'explicacion', order:null, recordKey:'pregunta_id', fields:[['pregunta_id','Pregunta',1,'select','questions'],['opcion_correcta_id','Opción correcta',1,'select','options'],['explicacion','Explicación',1]] },
  { key:'events', table:'eventos', label:'Eventos', title:'titulo', order:null, publish:'estado', fields:[['slug','Slug',1],['titulo','Título',1],['descripcion','Descripción',1],['inicia_en','Inicio',1],['termina_en','Fin',1],['estado','Estado',1],['es_prueba','Solo pruebas',0,'boolean']] },
  { key:'challenges', table:'desafios', label:'Desafíos', title:'titulo', order:'orden', publish:'estado', fields:[['evento_id','Evento',1,'select','events'],['slug','Slug',1],['titulo','Título',1],['descripcion','Descripción',1],['dificultad','Dificultad',1],['duracion_segundos','Duración (segundos)',1,'number'],['puntos_por_acierto','Puntos por acierto',1,'number'],['intentos_permitidos','Intentos permitidos',1,'number'],['tolerancia_segundos','Tolerancia (segundos)',1,'number'],['orden','Orden',1,'number'],['estado','Estado',1],['es_prueba','Solo pruebas',0,'boolean']] },
  { key:'challengeQuestions', table:'desafio_preguntas', label:'Preguntas de desafíos', title:'enunciado', order:'orden', fields:[['desafio_id','Desafío',1,'select','challenges'],['orden','Orden',1,'number'],['enunciado','Enunciado',1],['codigo','Código opcional',0],['dificultad','Dificultad',1]] },
  { key:'challengeOptions', table:'desafio_opciones', label:'Opciones de desafíos', title:'texto', order:'orden', fields:[['pregunta_id','Pregunta de desafío',1,'select','challengeQuestions'],['orden','Orden',1,'number'],['texto','Texto',1]] },
  { key:'challengeSolutions', table:'desafio_soluciones', label:'Soluciones de desafíos', title:'explicacion', order:null, recordKey:'pregunta_id', fields:[['pregunta_id','Pregunta de desafío',1,'select','challengeQuestions'],['opcion_correcta_id','Opción correcta',1,'select','challengeOptions'],['explicacion','Explicación',1]] }
].map(item => ({ ...item, fields:item.fields.map(([key,label,requiredFlag,type,parent]) => ({ key,label,required:!!requiredFlag,type,parent })) }))
const current = computed(() => entities.find(item => item.key === tab.value) || entities[0])
const filteredItems = computed(() => rows.value.filter(row => JSON.stringify(row).toLowerCase().includes(filter.value.toLowerCase())).sort((a,b) => (Number(a[current.value.order]) || 0) - (Number(b[current.value.order]) || 0)))
function subtitle(row) { const state = row.estado || (row.disponible === true ? 'publicado' : row.disponible === false ? 'borrador' : ''); const parent = current.value.fields.map(field => field.parent && parents.value[field.parent]?.find(x => x.id === row[field.key])?.label).filter(Boolean).join(' · '); return [parent, state, current.value.order ? `orden ${row[current.value.order]}` : ''].filter(Boolean).join(' · ') }
function isPublished(row) { return row.disponible === true || ['disponible','publicado','cerrado'].includes(row.estado) }
function optionsFor(field) { return (parents.value[field.parent] || []).map(item => ({ label:item.label, value:item.id })) }
watch(current, async item => { filter.value=''; await loadEntity(item) })
watch(dialog, open => { if (!open) formError.value='' })
async function check() { const { data, error } = await db.rpc('es_admin'); authorized.value = !error && data === true; if (authorized.value) { await loadParents(); await loadEntity(current.value) } }
async function loadParents() {
  const sources = [
    ['courses','cursos','id, titulo'],['units','unidades','id, titulo'],['lessons','lecciones','id, titulo'],['questions','preguntas','id, enunciado'],['options','opciones','id, texto'],['events','eventos','id, titulo'],['challenges','desafios','id, titulo'],['challengeQuestions','desafio_preguntas','id, enunciado'],['challengeOptions','desafio_opciones','id, texto']
  ]
  for (const [key, table, select] of sources) { const { data } = await db.from(table).select(select).order('orden', { ascending:true, nullsFirst:false }); parents.value[key] = (data || []).map(row => ({ id:row.id, label:row.titulo || row.enunciado || row.texto })) }
}
async function loadEntity(item) { loading.value=true; const query=db.from(item.table).select('*'); if (item.order) query.order(item.order); else query.order('creado_en', { ascending:false, nullsFirst:false }); const { data }=await query; rows.value=data||[]; loading.value=false }
function createItem() { const value={}; current.value.fields.forEach(field => { value[field.key]=field.type==='boolean' ? false : field.type==='number' ? 1 : '' }); form.value=value; dialog.value=true }
function editItem(row) { form.value={...row, id:row[current.value.recordKey || 'id'] || row.id}; dialog.value=true }
function fieldOptions(field) { return field.parent ? optionsFor(field) : field.key==='estado' ? (current.value.table==='cursos' ? [{label:'Disponible',value:'disponible'},{label:'Próximamente',value:'proximamente'}] : [{label:'Borrador',value:'borrador'},{label:'Publicado',value:'publicado'},{label:'Cerrado',value:'cerrado'}]) : field.key==='dificultad' ? ['facil','intermedio','dificil'].map(value=>({label:value,value})) : null }
async function saveItem() { saving.value=true; formError.value=''; const payload={}; current.value.fields.forEach(field=>{ if (form.value[field.key] !== '' && form.value[field.key] !== undefined) payload[field.key]=field.type==='number' ? Number(form.value[field.key]) : form.value[field.key] }); const key=current.value.recordKey || 'id'; const hasRecord=!!form.value[key]; const query=hasRecord ? db.from(current.value.table).update(payload).eq(key,form.value[key]) : db.from(current.value.table).insert(payload); const { error }=await query; if(error) formError.value=error.message; else { dialog.value=false; await loadParents(); await loadEntity(current.value) } saving.value=false }
async function togglePublish(row) { if (!window.confirm('¿Confirmás cambiar el estado de publicación? El historial se conserva.')) return; const patch=row.disponible !== undefined ? { disponible:!row.disponible } : { estado:row.estado==='publicado' ? 'cerrado' : 'publicado' }; const { error }=await db.from(current.value.table).update(patch).eq('id',row.id); if(error) window.alert(error.message); await loadEntity(current.value) }
onMounted(check)
</script>

<style scoped>
.admin-page{min-height:100vh;background:linear-gradient(135deg,#eef8e9,#fff9e9);color:#263524}.admin-page__shell{max-width:1180px;margin:auto;padding:42px 4vw}.admin-page__header{display:flex;justify-content:space-between;align-items:flex-start;gap:20px;margin-bottom:22px}.admin-page h1{margin:5px 0;font-size:clamp(2rem,4vw,3.5rem);letter-spacing:-.05em}.admin-page p{color:#697766}.eyebrow{color:#58a700;font-size:.72rem;font-weight:900;letter-spacing:.14em;text-transform:uppercase}.denied{background:#fff1d6}.tabs{margin-bottom:18px;background:#ffffffc9;border-radius:16px;border:1px solid #dbe8d3}.panel{padding:26px;border:1px solid #dcebd5;border-radius:24px;background:#fffffff0;box-shadow:0 18px 50px #76975d20}.panel__bar{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:20px}.panel h2{margin:4px 0 0;font-size:1.7rem}.filter{max-width:420px;margin-bottom:18px}.items{border-radius:14px;overflow:hidden}.actions{display:flex;flex-direction:row;gap:3px}.state,.empty{text-align:center;padding:42px;color:#71806c}.form-card{width:min(620px,94vw);max-height:90vh;overflow:auto;padding:8px}.form-card h2{margin:5px 0 18px}.form-error{margin-top:14px;background:#fff0ee;color:#9a3028}
@media(max-width:700px){.admin-page__header{flex-direction:column}.panel{padding:16px}.tabs{max-width:100%;overflow:hidden}.panel__bar{align-items:flex-start;flex-direction:column}.panel__bar .q-btn{width:100%}}
</style>
