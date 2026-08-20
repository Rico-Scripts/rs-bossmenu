const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => document.querySelectorAll(selector);

const app = $('#app');

let state = {
    job: null,
    balance: 0,
    employees: [],
    grades: [],
    logs: []
};

function safe(value) {
    const span = document.createElement('span');
    span.textContent = value ?? '';
    return span.innerHTML;
}

function money(value) {
    return new Intl.NumberFormat('nl-NL').format(Number(value) || 0);
}

async function post(name, data = {}) {
    try {
        const response = await fetch(
            `https://${GetParentResourceName()}/${name}`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            }
        );

        const text = await response.text();
        return text ? JSON.parse(text) : {};
    } catch (error) {
        console.error('[rs-bossmenu]', name, error);
        return { success: false, message: 'NUI fout.' };
    }
}

function notice(message, ok = true) {
    $('#notice').innerHTML = `<span class="${ok ? 'ok' : 'bad'}">${safe(message || '')}</span>`;
    setTimeout(() => $('#notice').innerHTML = '', 3000);
}

function setView(name) {
    $$('.tab').forEach((button) => {
        button.classList.toggle('active', button.dataset.view === name);
    });

    $$('.view').forEach((view) => view.classList.remove('active'));

    const target = $(`#${name}View`);
    if (target) target.classList.add('active');
}

function gradeOptions(selected) {
    return state.grades.map((grade) => `
        <option value="${Number(grade.grade)}" ${Number(grade.grade) === Number(selected) ? 'selected' : ''}>
            ${safe(grade.label)} (${Number(grade.grade)})
        </option>
    `).join('');
}

function render() {
    $('#jobLabel').textContent = state.job?.label || state.job?.name || 'Bedrijf';
    $('#balance').textContent = `€${money(state.balance)}`;
    $('#employeeCount').textContent = state.employees.length;
    $('#gradeCount').textContent = state.grades.length;

    $('#employees').innerHTML = state.employees.length
        ? state.employees.map((employee) => {
            const name = `${employee.firstname || ''} ${employee.lastname || ''}`.trim() || employee.identifier;

            return `
                <div class="employee">
                    <div>
                        <strong>${safe(name)}</strong>
                        <small>${safe(employee.identifier)}</small>
                    </div>

                    <select class="employee-grade" data-identifier="${safe(employee.identifier)}">
                        ${gradeOptions(employee.job_grade)}
                    </select>

                    <button class="danger fire" data-identifier="${safe(employee.identifier)}">
                        Ontslaan
                    </button>
                </div>
            `;
        }).join('')
        : '<div class="empty">Geen medewerkers gevonden.</div>';

    $$('.employee-grade').forEach((select) => {
        select.addEventListener('change', async () => {
            const result = await post('setGrade', {
                identifier: select.dataset.identifier,
                grade: Number(select.value)
            });

            notice(result.message, result.success);
            if (result.success) await refresh();
        });
    });

    $$('.fire').forEach((button) => {
        button.addEventListener('click', async () => {
            if (!confirm('Deze medewerker ontslaan?')) return;

            const result = await post('fire', {
                identifier: button.dataset.identifier
            });

            notice(result.message, result.success);
            if (result.success) await refresh();
        });
    });

    $('#logs').innerHTML = state.logs.length
        ? state.logs.map((entry) => `
            <div class="log-row">
                <span>${safe(entry.created_at)}</span>
                <span>${safe(entry.action)}</span>
                <span>${safe(entry.identifier || '-')}</span>
            </div>
        `).join('')
        : '<div class="empty">Nog geen logregels.</div>';
}

async function refresh() {
    const result = await post('refresh');

    if (!result.success) {
        notice(result.message, false);
        return;
    }

    state = result.data || state;
    render();
}

$$('.tab').forEach((button) => {
    button.addEventListener('click', () => setView(button.dataset.view));
});

$('#hire').addEventListener('click', async () => {
    const serverId = Number($('#hireId').value);

    if (!serverId) {
        return notice('Vul een server ID in.', false);
    }

    const result = await post('hire', { serverId });
    notice(result.message, result.success);

    if (result.success) {
        $('#hireId').value = '';
        await refresh();
    }
});

$('#deposit').addEventListener('click', async () => {
    const amount = Number($('#depositAmount').value);
    const result = await post('deposit', { amount });
    notice(result.message, result.success);
    if (result.success) await refresh();
});

$('#withdraw').addEventListener('click', async () => {
    const amount = Number($('#withdrawAmount').value);
    const result = await post('withdraw', { amount });
    notice(result.message, result.success);
    if (result.success) await refresh();
});

$('#close').addEventListener('click', async () => {
    app.classList.add('hidden');
    await post('close');
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') $('#close').click();
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        state = data.data || state;
        render();
        setView('overview');
        app.classList.remove('hidden');
    }
});
